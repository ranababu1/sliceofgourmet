import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/recipe_repository.dart';
import 'data/wordpress_repository.dart';
import 'data/wordpress_api.dart';
import 'data/recipe.dart';
import '../../core/cache/local_store.dart';

import 'package:shared_preferences/shared_preferences.dart';

// Swap baseUrl if you use a staging site
const _baseUrl = 'https://sliceofgourmet.com';

final _apiProvider = Provider<WordPressApi>((ref) => WordPressApi(_baseUrl));
final _storeProvider = Provider<LocalStore>((ref) => LocalStore.instance);

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return WordPressRecipeRepository(
    ref.read(_apiProvider),
    ref.read(_storeProvider),
  );
});

// Data providers
final trendingRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.fetchTrending(limit: 10);
});

final latestRecipesProvider = FutureProvider.family<List<Recipe>, int>((
  ref,
  page,
) async {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.fetchLatest(page: page, pageSize: 20);
});

final categoriesProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.fetchCategories();
});

final searchResultsProvider = FutureProvider.family<List<Recipe>, String>((
  ref,
  query,
) async {
  final repo = ref.watch(recipeRepositoryProvider);
  if (query.trim().isEmpty) return [];
  return repo.search(query.trim());
});

// bookmarks
final bookmarkIdsNotifierProvider =
    StateNotifierProvider<BookmarkIdsNotifier, Set<String>>((ref) {
      return BookmarkIdsNotifier();
    });

class BookmarkIdsNotifier extends StateNotifier<Set<String>> {
  BookmarkIdsNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('bookmarks') ?? [];
    state = ids.toSet();
  }

  Future<void> toggle(String id) async {
    final next = Set<String>.from(state);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('bookmarks', state.toList());
  }
}

final bookmarksProvider = Provider<Set<String>>(
  (ref) => ref.watch(bookmarkIdsNotifierProvider),
);

final bookmarkedRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final repo = ref.watch(recipeRepositoryProvider);
  final ids = ref.watch(bookmarksProvider);
  final futures = ids.map((id) => repo.fetchById(id));
  return Future.wait(futures);
});
