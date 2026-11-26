import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/recipe_repository.dart';
import 'data/wordpress_repository.dart';
import 'data/wordpress_api.dart';
import 'data/recipe.dart';
import 'data/category.dart';
import '../../core/cache/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Site the app reads from. Override for staging or local testing:
///   --dart-define=SOG_BASE_URL=https://staging.example
const kSiteBaseUrl = String.fromEnvironment('SOG_BASE_URL',
    defaultValue: 'https://sliceofgourmet.com');

final sogApiProvider = Provider<SogApi>((ref) => SogApi(kSiteBaseUrl));
final localStoreProvider = Provider<LocalStore>((ref) => LocalStore.instance);

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return WordPressRecipeRepository(
      ref.read(sogApiProvider), ref.read(localStoreProvider));
});

/// Full recipe for the detail screen.
final recipeByIdProvider =
    FutureProvider.family<RecipeDetail, String>((ref, id) async {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.fetchById(id);
});

final trendingRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.fetchTrending(limit: 10);
});

final latestRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.fetchLatest(limit: 20);
});

final categoriesProvider = FutureProvider<List<RecipeCategory>>((ref) async {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.fetchCategories();
});

final topCategoriesProvider = FutureProvider<List<RecipeCategory>>((ref) async {
  final list = await ref.watch(categoriesProvider.future);
  return list.take(5).toList(growable: false);
});

final categoryRecipesProvider =
    FutureProvider.family<List<Recipe>, int>((ref, id) async {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.fetchByCategory(id);
});

final searchResultsProvider =
    FutureProvider.family<List<Recipe>, String>((ref, query) async {
  final repo = ref.watch(recipeRepositoryProvider);
  final q = query.trim();
  if (q.isEmpty) return [];
  return repo.search(q);
});

/// Resolves a shared sliceofgourmet.com link to a post id (null if it is
/// not a recipe).
final linkResolverProvider =
    FutureProvider.family<String?, String>((ref, url) async {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.resolveLink(Uri.parse(url));
});

// bookmarks
const _bookmarksKey = 'bookmarks';
const _bookmarksVersionKey = 'bookmarks_v';

final bookmarkIdsNotifierProvider =
    StateNotifierProvider<BookmarkIdsNotifier, Set<String>>((ref) {
  return BookmarkIdsNotifier();
});

/// Saved recipe ids. These are WordPress post ids, which did not change in
/// the move from WP Recipe Maker to sog-recipes, so v1 bookmarks carry over.
class BookmarkIdsNotifier extends StateNotifier<Set<String>> {
  BookmarkIdsNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    var ids = prefs.getStringList(_bookmarksKey) ?? [];
    if (prefs.getInt(_bookmarksVersionKey) != 2) {
      // drop anything that is not a numeric post id
      ids = ids.where((e) => int.tryParse(e) != null).toSet().toList();
      await prefs.setStringList(_bookmarksKey, ids);
      await prefs.setInt(_bookmarksVersionKey, 2);
    }
    if (!mounted) return;
    // keep anything toggled before loading finished
    state = {...ids, ...state};
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_bookmarksKey, state.toList());
  }

  Future<void> toggle(String id) async {
    final next = Set<String>.from(state);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = next;
    await _save();
  }

  Future<void> removeAll(Iterable<String> ids) async {
    state = state.difference(ids.toSet());
    await _save();
  }
}

final bookmarksProvider =
    Provider<Set<String>>((ref) => ref.watch(bookmarkIdsNotifierProvider));

class BookmarkedRecipes {
  const BookmarkedRecipes(this.items,
      {this.goneIds = const {}, this.failed = 0});
  final List<Recipe> items;

  /// Saved recipes the site says no longer exist.
  final Set<String> goneIds;

  /// Saved recipes that could not be loaded (offline and not cached).
  final int failed;
}

/// Loads bookmarked recipes; individual failures are reported instead of
/// failing the whole list.
final bookmarkedRecipesProvider =
    FutureProvider<BookmarkedRecipes>((ref) async {
  final repo = ref.watch(recipeRepositoryProvider);
  final ids = ref.watch(bookmarksProvider);
  final gone = <String>{};
  var failed = 0;
  final store = ref.read(localStoreProvider);
  final results = await Future.wait(ids.map((id) async {
    // the synced catalog already has the card, no request needed
    final card = store.readCard(id);
    if (card != null) return Recipe.fromJson(card);
    try {
      return await repo.fetchById(id);
    } on RecipeNotFoundException {
      gone.add(id);
    } catch (_) {
      failed++;
    }
    return null;
  }));
  return BookmarkedRecipes(results.whereType<Recipe>().toList(),
      goneIds: gone, failed: failed);
});
