import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/recipes/data/recipe_repository.dart';
import '../../features/recipes/providers.dart'; // needed for recipeRepositoryProvider
import '../cache/local_store.dart';

final localStoreProvider = Provider<LocalStore>((ref) => LocalStore.instance);

final hydratorProvider = Provider<Hydrator>((ref) {
  final store = ref.read(localStoreProvider);
  final repo = ref.read(recipeRepositoryProvider);
  return Hydrator(store, repo);
});

final lastHydratedProvider = StateProvider<DateTime?>((ref) {
  return ref.read(localStoreProvider).lastHydratedAt;
});

class Hydrator {
  Hydrator(this.store, this.repo);
  final LocalStore store;
  final RecipeRepository repo;

  bool _checkedThisSession = false;

  Future<void> ensureDailyHydration() async {
    if (_checkedThisSession) return;
    _checkedThisSession = true;

    final last = store.lastHydratedAt;
    final now = DateTime.now();
    if (last == null || now.difference(last).inHours >= 24) {
      await hydrate();
    }
  }

  /// Refresh home essentials, only update cache on success
  Future<bool> hydrate() async {
    try {
      await repo.fetchTrending(limit: 10);
      await repo.fetchLatest(page: 1, pageSize: 20);
      await repo.fetchCategories();
      await store.setLastHydratedAt(DateTime.now());
      return true;
    } catch (_) {
      // keep existing cache untouched on failures
      return false;
    }
  }
}
