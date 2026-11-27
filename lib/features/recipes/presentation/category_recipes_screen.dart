import '../../profile/name_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../recipes/providers.dart';
import '../../../core/widgets/recipe_card.dart';
import '../../../core/widgets/skeletons.dart';
import '../../../core/widgets/state_views.dart';
import 'home_screen.dart' show refreshAndReport;

class CategoryRecipesScreen extends ConsumerWidget {
  const CategoryRecipesScreen(
      {super.key, required this.categoryId, this.categoryName});
  final int categoryId;
  final String? categoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoryRecipesProvider(categoryId));
    final saved = ref.watch(bookmarksProvider);
    void toggle(String id) => toggleSavedRecipe(context, ref, id);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => refreshAndReport(context, ref),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar.large(title: Text(categoryName ?? 'Recipes')),
            ...async.when(
              loading: () => [
                const SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    sliver: ShimmerRecipeGrid()),
              ],
              error: (e, st) => [
                SliverFillRemaining(
                  child: MessageView(
                    message: kOfflineMessage,
                    icon: Icons.cloud_off_rounded,
                    onRetry: () =>
                        ref.invalidate(categoryRecipesProvider(categoryId)),
                  ),
                ),
              ],
              data: (items) => [
                if (items.isEmpty)
                  const SliverFillRemaining(
                    child: MessageView(
                        message: 'No recipes in this category yet.',
                        icon: Icons.menu_book_outlined),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: RecipeSliverGrid(
                        items: items,
                        saved: saved,
                        onToggleSave: toggle,
                        heroScope: 'cat$categoryId'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
