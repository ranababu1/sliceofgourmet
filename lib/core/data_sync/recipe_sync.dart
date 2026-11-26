import '../../features/recipes/data/category.dart';
import '../../features/recipes/data/recipe.dart';
import '../../features/recipes/data/wordpress_api.dart';
import '../cache/local_store.dart';

/// Category slug whose posts fill the home "Trending" carousel.
const kFeaturedCategorySlug = 'featured';

class SyncReport {
  const SyncReport(
      {this.added = 0,
      this.updated = 0,
      this.removed = 0,
      this.firstRun = false});
  final int added;
  final int updated;
  final int removed;
  final bool firstRun;
  bool get changed => added + updated + removed > 0;
}

/// Keeps the on-device catalog in step with the site while asking the
/// server for as little as possible:
///
/// 1. `GET sog/v1/manifest` with If-None-Match. A 304 (no body, usually a
///    LiteSpeed cache hit) means nothing changed and sync stops.
/// 2. Otherwise `GET sog/v1/recipes/ids` (id + modified time for every
///    recipe) tells us which recipes are new, changed or gone.
/// 3. Only changed recipes are downloaded, via `modified_after`.
///
/// The first run pages through the catalog 50 cards at a time.
class RecipeSync {
  RecipeSync(this.api, this.store, {this.pageSize = 50});
  final SogApi api;
  final LocalStore store;
  final int pageSize;

  Future<SyncReport> sync(
      {void Function(int done, int total)? onProgress}) async {
    if (!store.hasCatalog) return _full(onProgress);
    return _incremental();
  }

  Future<SyncReport> _full(void Function(int, int)? onProgress) async {
    final cards = <String, Map<String, dynamic>>{};
    final order = <String>[];
    var page = 1;
    int? totalPages;
    int? total;
    while (true) {
      final res = await api.fetchRecipes(page: page, perPage: pageSize);
      totalPages ??= res.totalPages;
      total ??= res.total;
      for (final j in res.items) {
        final r = Recipe.fromJson(j);
        if (r.id.isEmpty || cards.containsKey(r.id)) continue;
        cards[r.id] = r.toJson();
        order.add(r.id);
      }
      onProgress?.call(cards.length, total ?? cards.length);
      if (res.items.length < pageSize) break;
      if (totalPages != null && page >= totalPages) break;
      page++;
    }

    final manifest = await _manifestOrNull();
    final ids = await api.fetchIds();
    await store.writeCards(cards);
    await store.setCatalogIds(order);
    await store.setEtag('ids', ids.etag);
    await _syncTrending();
    await _syncCategories();
    await _saveManifest(manifest);
    return SyncReport(added: order.length, firstRun: true);
  }

  Future<Fetched<Manifest>?> _manifestOrNull({String? etag}) async {
    try {
      return await api.fetchManifest(etag: etag);
    } on ApiException {
      return null;
    }
  }

  Future<void> _saveManifest(Fetched<Manifest>? m) async {
    if (m == null || m.notModified) return;
    await store.setEtag('manifest', m.etag);
    await store.setEtag('categories', m.data!.categoriesEtag);
  }

  Future<SyncReport> _incremental() async {
    final manifest = await _manifestOrNull(etag: store.etag('manifest'));
    if (manifest != null && manifest.notModified) return const SyncReport();

    final ids = await api.fetchIds(etag: store.etag('ids'));
    var report = const SyncReport();
    if (!ids.notModified) report = await _applyIds(ids);

    final catsChanged = manifest?.data == null ||
        manifest!.data!.categoriesEtag != store.etag('categories');
    if (report.changed) await _syncTrending();
    if (report.changed || catsChanged) await _syncCategories();
    await _saveManifest(manifest);
    return report;
  }

  Future<SyncReport> _applyIds(Fetched<List<RemoteId>> fetched) async {
    final remote = fetched.data!;
    final remoteIds = remote.map((e) => e.id).toSet();
    final local = store.catalogIds ?? const <String>[];
    final removed = local.where((id) => !remoteIds.contains(id)).toList();

    final changed = <RemoteId>[];
    for (final r in remote) {
      final card = store.readCard(r.id);
      if (card == null || !local.contains(r.id)) {
        changed.add(r);
      } else if (normGmt('${card['modified_gmt'] ?? ''}') !=
          normGmt(r.modifiedGmt)) {
        changed.add(r);
      }
    }

    final fresh = <String, Map<String, dynamic>>{};
    if (changed.isNotEmpty) {
      final since = changed
          .map((e) => DateTime.tryParse('${normGmt(e.modifiedGmt)}Z'))
          .whereType<DateTime>()
          .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
      final want = changed.map((e) => e.id).toSet();
      var page = 1;
      while (true) {
        final res = await api.fetchRecipes(
          page: page,
          perPage: pageSize,
          modifiedAfter: since
              ?.subtract(const Duration(seconds: 1))
              .toIso8601String()
              .split('.')
              .first,
        );
        for (final j in res.items) {
          final r = Recipe.fromJson(j);
          if (want.contains(r.id)) fresh[r.id] = r.toJson();
        }
        if (res.items.length < pageSize ||
            (res.totalPages != null && page >= res.totalPages!)) {
          break;
        }
        page++;
      }
    }

    // a full recipe saved before the change is stale now
    for (final id in fresh.keys) {
      final post = store.readPost(id);
      if (post != null &&
          normGmt('${post['modified_gmt'] ?? ''}') !=
              normGmt('${fresh[id]!['modified_gmt'] ?? ''}')) {
        await store.deletePost(id);
      }
    }
    for (final id in removed) {
      await store.deleteRecipe(id);
    }
    await store.writeCards(fresh);
    await store.setCatalogIds(remote
        .map((e) => e.id)
        .where((id) => fresh.containsKey(id) || store.readCard(id) != null)
        .toList());
    await store.setEtag('ids', fetched.etag);
    final gotAdded = changed
        .where((e) => fresh.containsKey(e.id) && !local.contains(e.id))
        .length;
    return SyncReport(
        added: gotAdded,
        updated: fresh.length - gotAdded,
        removed: removed.length);
  }

  Future<void> _syncTrending() async {
    final res =
        await api.fetchRecipes(perPage: 10, category: kFeaturedCategorySlug);
    final ids = <String>[];
    final cards = <String, Map<String, dynamic>>{};
    for (final j in res.items) {
      final r = Recipe.fromJson(j);
      if (r.id.isEmpty) continue;
      ids.add(r.id);
      cards[r.id] = r.toJson();
    }
    await store.writeCards(cards);
    await store.setTrendingIds(ids);
  }

  Future<void> _syncCategories() async {
    final List<RecipeCategory> cats = await api.fetchCategories();
    await store.writeCategories(cats.map((e) => e.toJson()).toList());
  }
}

/// "2026-11-16T23:03:36" from any GMT timestamp shape the API or cache uses.
String normGmt(String s) {
  var t = s.trim();
  if (t.endsWith('Z')) t = t.substring(0, t.length - 1);
  final plus = t.indexOf('+', 10);
  if (plus > 0) t = t.substring(0, plus);
  return t.split('.').first;
}
