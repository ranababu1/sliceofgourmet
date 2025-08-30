import 'recipe.dart';
import 'recipe_repository.dart';
import 'wordpress_api.dart';
import '../../../core/cache/local_store.dart';

class WordPressRecipeRepository implements RecipeRepository {
  WordPressRecipeRepository(this.api, this.store);
  final WordPressApi api;
  final LocalStore store;

  // persist posts into local cache
  Future<void> _persistPosts(List<Recipe> items) async {
    for (final r in items) {
      await store.writePost(r.id, r.toJson());
    }
  }

  // read posts by id list from cache
  List<Recipe> _readPostsByIds(List<String> ids) {
    final results = <Recipe>[];
    for (final id in ids) {
      final json = store.readPost(id);
      if (json != null) {
        results.add(Recipe.fromJson(json));
      }
    }
    return results;
  }

  @override
  Future<List<Recipe>> fetchTrending({int limit = 10}) async {
    // 1, try cached ids
    final cachedIds = store.trendingIds;
    if (cachedIds != null && cachedIds.isNotEmpty) {
      final cached = _readPostsByIds(cachedIds);
      if (cached.isNotEmpty) return cached;
    }

    // 2, network sticky posts first
    final stickyList = await api.fetchPosts(
      page: 1,
      perPage: limit,
      sticky: true,
    );
    List<Recipe> items;
    if (stickyList.isNotEmpty) {
      items = stickyList
          .map((e) => Recipe.fromWpJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } else {
      final latestList = await api.fetchPosts(page: 1, perPage: limit);
      items = latestList
          .map((e) => Recipe.fromWpJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    }

    await _persistPosts(items);
    await store.setTrendingIds(items.map((e) => e.id).toList(growable: false));
    return items;
  }

  @override
  Future<List<Recipe>> fetchLatest({int page = 1, int pageSize = 20}) async {
    final key = 'latest_page_$page';

    // 1, cache
    final cachedIds = store.readIdList(key);
    if (cachedIds != null && cachedIds.isNotEmpty) {
      final cached = _readPostsByIds(cachedIds);
      if (cached.isNotEmpty) return cached;
    }

    // 2, network
    final list = await api.fetchPosts(page: page, perPage: pageSize);
    final items = list
        .map((e) => Recipe.fromWpJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);

    await _persistPosts(items);
    await store.writeIdList(
      key,
      items.map((e) => e.id).toList(growable: false),
    );
    if (page == 1) {
      await store.setLatestPage1Ids(
        items.map((e) => e.id).toList(growable: false),
      );
    }
    return items;
  }

  @override
  Future<Recipe> fetchById(String id) async {
    // cache first
    final cached = store.readPost(id);
    if (cached != null) {
      return Recipe.fromJson(cached);
    }

    final j = await api.fetchPostById(id);
    final r = Recipe.fromWpJson(Map<String, dynamic>.from(j));
    await store.writePost(r.id, r.toJson());
    return r;
  }

  @override
  Future<List<String>> fetchCategories() async {
    final cached = store.getCategoryNames();
    if (cached != null && cached.isNotEmpty) return cached;

    final cats = await api.fetchCategories();
    if (cats.isNotEmpty) {
      await store.setCategoryNames(cats.toList(growable: false));
    }
    return cats;
  }

  @override
  Future<List<Recipe>> search(
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final list = await api.searchPosts(query, page: page, perPage: pageSize);
    final items = list
        .map((e) => Recipe.fromWpJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
    // persist for offline detail, do not touch home lists here
    await _persistPosts(items);
    return items;
  }

  @override
  Future<List<Recipe>> fetchByCategory(
    String category, {
    int page = 1,
    int pageSize = 20,
  }) {
    // simple fallback using WP search
    return search(category, page: page, pageSize: pageSize);
  }
}
