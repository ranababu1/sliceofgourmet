import 'recipe.dart';
import 'recipe_repository.dart';
import 'wordpress_api.dart';
import 'category.dart';
import '../../../core/cache/local_store.dart';

class WordPressRecipeRepository implements RecipeRepository {
  WordPressRecipeRepository(this.api, this.store);
  final WordPressApi api;
  final LocalStore store;

  Future<void> _persistPosts(List<Recipe> items) async {
    for (final r in items) {
      await store.writePost(r.id, r.toJson());
    }
  }

  List<Recipe> _readPostsByIds(List<String> ids) {
    final results = <Recipe>[];
    for (final id in ids) {
      final json = store.readPost(id);
      if (json != null) results.add(Recipe.fromJson(json));
    }
    return results;
  }

  @override
  Future<List<Recipe>> fetchTrending({int limit = 10}) async {
    final cachedIds = store.trendingIds;
    if (cachedIds != null && cachedIds.isNotEmpty) {
      final cached = _readPostsByIds(cachedIds);
      if (cached.isNotEmpty) return cached;
    }

    final stickyList = await api.fetchPosts(
      page: 1,
      perPage: limit,
      sticky: true,
    );
    List<Recipe> items;
    if (stickyList.isNotEmpty) {
      items = stickyList
          .map((e) => Recipe.fromWpJson(e))
          .toList(growable: false);
    } else {
      final latestList = await api.fetchPosts(page: 1, perPage: limit);
      items = latestList
          .map((e) => Recipe.fromWpJson(e))
          .toList(growable: false);
    }

    await _persistPosts(items);
    await store.setTrendingIds(items.map((e) => e.id).toList(growable: false));
    return items;
  }

  @override
  Future<List<Recipe>> fetchLatest({int page = 1, int pageSize = 20}) async {
    final key = 'latest_page_$page';
    final cachedIds = store.readIdList(key);
    if (cachedIds != null && cachedIds.isNotEmpty) {
      final cached = _readPostsByIds(cachedIds);
      if (cached.isNotEmpty) return cached;
    }

    final list = await api.fetchPosts(page: page, perPage: pageSize);
    final items = list.map((e) => Recipe.fromWpJson(e)).toList(growable: false);

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
    final cached = store.readPost(id);
    if (cached != null) return Recipe.fromJson(cached);

    final j = await api.fetchPostById(id);
    final r = Recipe.fromWpJson(j);
    await store.writePost(r.id, r.toJson());
    return r;
  }

  @override
  Future<List<RecipeCategory>> fetchCategories() async {
    final cached = store.readCategories();
    if (cached != null && cached.isNotEmpty) {
      return cached.map((e) => RecipeCategory.fromJson(e)).toList();
    }
    final cats = await api.fetchCategoriesDetailed();
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
    final list = await api.searchPosts(query, page: page, perPage: pageSize);
    final items = list.map((e) => Recipe.fromWpJson(e)).toList(growable: false);
    await _persistPosts(items);
    return items;
  }

  @override
  Future<List<Recipe>> fetchByCategory(
    int categoryId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final list = await api.fetchPosts(
      page: page,
      perPage: pageSize,
      categoryId: categoryId,
    );
    final items = list.map((e) => Recipe.fromWpJson(e)).toList(growable: false);
    await _persistPosts(items);
    return items;
  }
}
