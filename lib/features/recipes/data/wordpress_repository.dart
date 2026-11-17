import 'recipe.dart';
import 'recipe_repository.dart';
import 'wordpress_api.dart';
import 'category.dart';
import '../../../core/cache/local_store.dart';

/// Category slug whose posts fill the home "Trending" carousel.
const kFeaturedCategorySlug = 'featured';

/// Hosts whose links the app opens itself.
const kSiteHosts = {'sliceofgourmet.com', 'www.sliceofgourmet.com'};

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

  Future<List<Recipe>> _parseAndPersist(List<Map<String, dynamic>> raw) async {
    final items = <Recipe>[];
    for (final j in raw) {
      final r = Recipe.fromJson(j);
      if (r.id.isEmpty) continue;
      items.add(r);
      await store.writeCard(r.id, r.toJson());
    }
    return items;
  }

  List<Recipe> _readCardsByIds(List<String> ids) {
    final results = <Recipe>[];
    for (final id in ids) {
      final json = store.readCard(id);
      if (json != null) results.add(Recipe.fromJson(json));
    }
    return results;
  }

  @override
  Future<List<Recipe>> fetchTrending(
      {int limit = 10, bool forceRefresh = false}) async {
    final cachedIds = store.trendingIds;
    if (!forceRefresh && cachedIds != null && cachedIds.isNotEmpty) {
      final cached = _readCardsByIds(cachedIds);
      if (cached.isNotEmpty) return cached;
    }

    var page =
        await api.fetchRecipes(perPage: limit, category: kFeaturedCategorySlug);
    if (page.items.isEmpty) page = await api.fetchRecipes(perPage: limit);
    final items = await _parseAndPersist(page.items);
    await store.setTrendingIds(items.map((e) => e.id).toList(growable: false));
    return items;
  }

  @override
  Future<List<Recipe>> fetchLatest(
      {int page = 1, int pageSize = 20, bool forceRefresh = false}) async {
    final key = 'latest_page_$page';
    final cachedIds = store.readIdList(key);
    if (!forceRefresh && cachedIds != null && cachedIds.isNotEmpty) {
      final cached = _readCardsByIds(cachedIds);
      if (cached.isNotEmpty) return cached;
    }

    final res = await api.fetchRecipes(page: page, perPage: pageSize);
    final items = await _parseAndPersist(res.items);
    final ids = items.map((e) => e.id).toList(growable: false);
    await store.writeIdList(key, ids);
    if (page == 1) await store.setLatestPage1Ids(ids);
    return items;
  }

  @override
  Future<RecipeDetail> fetchById(String id, {bool forceRefresh = false}) async {
    final cached = store.readPost(id);
    if (!forceRefresh && cached != null) return RecipeDetail.fromJson(cached);

    try {
      final j = await api.fetchRecipe(id);
      final r = RecipeDetail.fromJson(j);
      await store.writePost(r.id, r.toJson());
      return r;
    } on RecipeNotFoundException {
      await store.deleteRecipe(id);
      rethrow;
    } catch (_) {
      // offline: fall back to the saved copy even when forcing a refresh
      if (cached != null) return RecipeDetail.fromJson(cached);
      rethrow;
    }
  }

  @override
  Future<List<RecipeCategory>> fetchCategories(
      {bool forceRefresh = false}) async {
    final cached = store.readCategories();
    if (!forceRefresh && cached != null && cached.isNotEmpty) {
      return cached.map(RecipeCategory.fromJson).toList();
    }
    final cats = await api.fetchCategories();
    await store.writeCategories(
      cats.map((e) => e.toJson()).toList(growable: false),
    );
    return cats;
  }

  @override
  Future<List<Recipe>> search(
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final res =
        await api.fetchRecipes(search: query, page: page, perPage: pageSize);
    return _parseAndPersist(res.items);
  }

  @override
  Future<List<Recipe>> fetchByCategory(
    int categoryId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await api.fetchRecipes(
        page: page, perPage: pageSize, category: '$categoryId');
    return _parseAndPersist(res.items);
  }

  @override
  Future<String?> resolveLink(Uri link) async {
    final slug = recipeSlugFromLink(link);
    if (slug == null) return null;
    return api.resolveSlug(slug);
  }
}
