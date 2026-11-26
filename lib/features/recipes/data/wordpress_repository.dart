import 'recipe.dart';
import 'recipe_repository.dart';
import 'wordpress_api.dart';
import 'category.dart';
import '../../../core/cache/local_store.dart';
import '../../../core/data_sync/recipe_sync.dart' show normGmt;

/// Hosts whose links the app opens itself.
const kSiteHosts = {'sliceofgourmet.com', 'www.sliceofgourmet.com'};

/// Category slugs that are site plumbing, not something to browse.
const kHiddenCategorySlugs = {'featured', 'uncategorized'};

/// Permalinks are `/<category>/<child category>/<slug>/`. First path
/// segments that are never a recipe:
const _nonRecipePaths = {
  'category',
  'tag',
  'author',
  'page',
  'wp-admin',
  'wp-content',
  'wp-json',
  'feed',
  'search',
  'contact-me',
  'contact',
  'about',
  'cookie-policy',
  'privacy-policy',
  'faq',
};

/// Slug from a recipe permalink, or null when the link cannot be a recipe.
String? recipeSlugFromLink(Uri link) {
  if (link.hasScheme && !kSiteHosts.contains(link.host.toLowerCase())) {
    return null;
  }
  final segs = link.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segs.isEmpty || _nonRecipePaths.contains(segs.first)) return null;
  if (segs.last == 'print' || segs.last == 'amp') segs.removeLast();
  if (segs.length < 2) return null; // /<slug>/ is a page, not a recipe
  return segs.last;
}

class WordPressRecipeRepository implements RecipeRepository {
  WordPressRecipeRepository(this.api, this.store);
  final SogApi api;
  final LocalStore store;

  /// The on-device catalog, newest first.
  List<Recipe> get _catalog {
    final ids = store.catalogIds ?? const <String>[];
    final out = <Recipe>[];
    for (final id in ids) {
      final j = store.readCard(id);
      if (j != null) out.add(Recipe.fromJson(j));
    }
    return out;
  }

  Future<List<Recipe>> _network(Future<ApiPage> call) async {
    final res = await call;
    return res.items
        .map(Recipe.fromJson)
        .where((r) => r.id.isNotEmpty)
        .toList();
  }

  @override
  Future<List<Recipe>> fetchLatest({int limit = 20}) async {
    if (!store.hasCatalog) return _network(api.fetchRecipes(perPage: limit));
    return _catalog.take(limit).toList();
  }

  @override
  Future<List<Recipe>> fetchTrending({int limit = 10}) async {
    if (!store.hasCatalog) {
      return _network(api.fetchRecipes(perPage: limit, category: 'featured'));
    }
    final ids = store.trendingIds ?? const <String>[];
    final featured = [
      for (final id in ids)
        if (store.readCard(id) case final j?) Recipe.fromJson(j)
    ];
    if (featured.isNotEmpty) return featured.take(limit).toList();
    return _catalog.take(limit).toList();
  }

  @override
  Future<RecipeDetail> fetchById(String id) async {
    final cached = store.readPost(id);
    final card = store.readCard(id);
    final upToDate = cached != null &&
        (card == null ||
            normGmt('${card['modified_gmt'] ?? ''}') ==
                normGmt('${cached['modified_gmt'] ?? ''}'));
    if (upToDate) return RecipeDetail.fromJson(cached);

    try {
      final j = await api.fetchRecipe(id);
      final r = RecipeDetail.fromJson(j);
      await store.writePost(r.id, r.toJson());
      return r;
    } on RecipeNotFoundException {
      await store.deleteRecipe(id);
      rethrow;
    } catch (_) {
      // offline: an older saved copy beats an error
      if (cached != null) return RecipeDetail.fromJson(cached);
      rethrow;
    }
  }

  List<RecipeCategory> _storedCategories() =>
      (store.readCategories() ?? const [])
          .map(RecipeCategory.fromJson)
          .toList();

  /// [id] plus every category below it.
  Set<int> _withDescendants(int id, List<RecipeCategory> all) {
    final out = {id};
    var grew = true;
    while (grew) {
      grew = false;
      for (final c in all) {
        if (out.contains(c.parent) && out.add(c.id)) grew = true;
      }
    }
    return out;
  }

  @override
  Future<List<RecipeCategory>> fetchCategories() async {
    var cats = _storedCategories();
    if (cats.isEmpty) {
      cats = await api.fetchCategories();
      await store.writeCategories(cats.map((e) => e.toJson()).toList());
    }
    final visible = cats.where((c) => !kHiddenCategorySlugs.contains(c.slug));
    if (!store.hasCatalog) {
      return visible.where((c) => c.count > 0).toList()
        ..sort((a, b) => b.count.compareTo(a.count));
    }
    // counts that match what tapping the category shows
    final catalog = _catalog;
    final out = <RecipeCategory>[];
    for (final c in visible) {
      final ids = _withDescendants(c.id, cats);
      final n = catalog
          .where((r) => r.categories.any((t) => ids.contains(t.id)))
          .length;
      if (n > 0) {
        out.add(RecipeCategory(
            id: c.id, name: c.name, slug: c.slug, parent: c.parent, count: n));
      }
    }
    out.sort((a, b) => b.count.compareTo(a.count));
    return out;
  }

  @override
  Future<List<Recipe>> search(String query) async {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return const [];
    if (!store.hasCatalog) return _network(api.fetchRecipes(search: query));

    final scored = <(int, Recipe)>[];
    for (final r in _catalog) {
      final title = r.title.toLowerCase();
      final rest = [
        r.excerpt,
        ...r.cuisine,
        ...r.diet,
        ...r.categories.map((c) => c.name),
      ].join(' ').toLowerCase();
      if (!terms.every((t) => title.contains(t) || rest.contains(t))) continue;
      final score = terms.where(title.contains).length * 10 +
          (title.startsWith(terms.first) ? 5 : 0);
      scored.add((score, r));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return scored.map((e) => e.$2).toList();
  }

  @override
  Future<List<Recipe>> fetchByCategory(int categoryId) async {
    if (!store.hasCatalog) {
      return _network(api.fetchRecipes(category: '$categoryId', perPage: 50));
    }
    final ids = _withDescendants(categoryId, _storedCategories());
    return _catalog
        .where((r) => r.categories.any((t) => ids.contains(t.id)))
        .toList();
  }

  @override
  Future<String?> resolveLink(Uri link) async {
    final slug = recipeSlugFromLink(link);
    if (slug == null) return null;
    for (final r in _catalog) {
      if (r.slug == slug) return r.id;
    }
    return api.resolveSlug(slug);
  }
}
