import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../../../core/widgets/recipe_small_card.dart';
import '../../../core/widgets/state_views.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(bookmarkedRecipesProvider);
    final bookmarks = ref.watch(bookmarksProvider);

    if (bookmarks.isEmpty) {
      return const MessageView(
        message: 'No bookmarks yet. Tap the heart icon to save a recipe.',
        icon: Icons.favorite_border_rounded,
      );
    }

    return asyncItems.when(
      data: (items) {
        final missing = bookmarks.length - items.length;
        if (items.isEmpty) {
          return MessageView(
            message: kOfflineMessage,
            icon: Icons.cloud_off_rounded,
            onRetry: () => ref.invalidate(bookmarkedRecipesProvider),
          );
        }
        return Column(
          children: [
            if (missing > 0)
              MaterialBanner(
                content: Text(
                    '$missing saved recipe${missing == 1 ? '' : 's'} could not be loaded.'),
                actions: [
                  TextButton(
                    onPressed: () => ref.invalidate(bookmarkedRecipesProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: .78,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final r = items[index];
                  return Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: RecipeSmallCard(
                      recipe: r,
                      saved: bookmarks.contains(r.id),
                      onToggleSave: () => ref
                          .read(bookmarkIdsNotifierProvider.notifier)
                          .toggle(r.id),
                      height: 220,
                      width: double.infinity,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => MessageView(
        message: 'Could not load bookmarks',
        onRetry: () => ref.invalidate(bookmarkedRecipesProvider),
      ),
    );
  }
}
