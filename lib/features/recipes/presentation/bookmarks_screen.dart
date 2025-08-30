import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../../../core/widgets/recipe_card.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(bookmarkedRecipesProvider);
    final bookmarks = ref.watch(bookmarksProvider);

    if (bookmarks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No bookmarks yet. Tap the bookmark icon on a recipe to save it.',
          ),
        ),
      );
    }

    return asyncItems.when(
      data: (items) {
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: .72,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final r = items[index];
            final isBookmarked = bookmarks.contains(r.id);
            return RecipeCard(
              recipe: r,
              isBookmarked: isBookmarked,
              onBookmarkToggle: () =>
                  ref.read(bookmarkIdsNotifierProvider.notifier).toggle(r.id),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const Center(child: Text('Could not load bookmarks')),
    );
  }
}
