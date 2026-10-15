import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/recipes/data/recipe_repository.dart';
import '../../features/recipes/providers.dart';
import '../cache/local_store.dart';

final localStoreProvider = Provider<LocalStore>((ref) => LocalStore.instance);

final hydratorProvider = Provider<Hydrator>((ref) {
  return Hydrator(
    store: ref.read(localStoreProvider),
    repo: ref.read(recipeRepositoryProvider),
    onRefreshed: (at) {
      // make the UI re-read the fresh cache
      ref.invalidate(trendingRecipesProvider);
      ref.invalidate(latestRecipesProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(bookmarkedRecipesProvider);
      ref.read(lastHydratedProvider.notifier).state = at;
    },
  );
});

final lastHydratedProvider = StateProvider<DateTime?>((ref) {
  return ref.read(localStoreProvider).lastHydratedAt;
});

class Hydrator {
  Hydrator({required this.store, required this.repo, this.onRefreshed});
  final LocalStore store;
  final RecipeRepository repo;
  final void Function(DateTime at)? onRefreshed;

  bool _checkedThisSession = false;

  Future<void> ensureDailyHydration() async {
    if (_checkedThisSession) return;
    _checkedThisSession = true;

    final last = store.lastHydratedAt;
    if (last == null || DateTime.now().difference(last).inHours >= 24) {
      await hydrate();
    }
  }

  /// Fetch fresh home data from the network (bypassing cache).
  /// Cache is only overwritten on success.
  Future<bool> hydrate() async {
    try {
      await repo.fetchTrending(limit: 10, forceRefresh: true);
      await repo.fetchLatest(page: 1, pageSize: 20, forceRefresh: true);
      await repo.fetchCategories(forceRefresh: true);
      final now = DateTime.now();
      await store.setLastHydratedAt(now);
      onRefreshed?.call(now);
      return true;
    } catch (_) {
      return false;
    }
  }
}
