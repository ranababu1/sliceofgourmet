import '../../profile/name_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../../../core/widgets/recipe_card.dart';
import '../../../core/widgets/skeletons.dart';
import '../../../core/widgets/state_views.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(bookmarkedRecipesProvider);
    final bookmarks = ref.watch(bookmarksProvider);
    void toggle(String id) => toggleSavedRecipe(context, ref, id);

    List<Widget> body() {
      if (bookmarks.isEmpty) {
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: MessageView(
              message:
                  'Nothing saved yet. Tap the heart on any recipe to keep it here.',
              icon: Icons.favorite_border_rounded,
            ),
          ),
        ];
      }
      return asyncItems.when(
        loading: () => const [
          SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              sliver: ShimmerRecipeGrid(count: 4)),
        ],
        error: (e, st) => [
          SliverFillRemaining(
            child: MessageView(
              message: 'Could not load saved recipes',
              onRetry: () => ref.invalidate(bookmarkedRecipesProvider),
            ),
          ),
        ],
        data: (result) {
          final items =
              result.items.where((r) => bookmarks.contains(r.id)).toList();
          final gone = result.goneIds.intersection(bookmarks);
          if (items.isEmpty && gone.isEmpty) {
            return [
              SliverFillRemaining(
                child: MessageView(
                  message: kOfflineMessage,
                  icon: Icons.cloud_off_rounded,
                  onRetry: () => ref.invalidate(bookmarkedRecipesProvider),
                ),
              ),
            ];
          }
          return [
            if (gone.isNotEmpty)
              SliverToBoxAdapter(
                child: MaterialBanner(
                  content: Text(
                      '${gone.length} saved recipe${gone.length == 1 ? ' is' : 's are'} no longer on the site.'),
                  actions: [
                    TextButton(
                      onPressed: () => ref
                          .read(bookmarkIdsNotifierProvider.notifier)
                          .removeAll(gone),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ),
            if (result.failed > 0)
              SliverToBoxAdapter(
                child: MaterialBanner(
                  content: Text(
                      '${result.failed} saved recipe${result.failed == 1 ? '' : 's'} could not be loaded.'),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(bookmarkedRecipesProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              sliver: RecipeSliverGrid(
                  items: items,
                  saved: bookmarks,
                  onToggleSave: toggle,
                  heroScope: 'saved'),
            ),
          ];
        },
      );
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
            title: const Text('Saved'), automaticallyImplyLeading: false),
        ...body(),
      ],
    );
  }
}
