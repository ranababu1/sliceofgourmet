import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/recipe_repository.dart';
import 'data/recipe.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Swap this to the real WordPress repository later.
final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return MockRecipeRepository();
});

/// Latest feed with pagination
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

/// Bookmarks controller made public so other files can import it.
/// We expose both the Set<String> state and a helper toggle.
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

/// Read only view of bookmark ids, for convenience.
final bookmarksProvider = Provider<Set<String>>(
  (ref) => ref.watch(bookmarkIdsNotifierProvider),
);

final bookmarkedRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final repo = ref.watch(recipeRepositoryProvider);
  final ids = ref.watch(bookmarksProvider);
  final futures = ids.map((id) => repo.fetchById(id));
  return Future.wait(futures);
});
