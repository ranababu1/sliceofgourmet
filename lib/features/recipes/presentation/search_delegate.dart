import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../../../core/widgets/recipe_small_card.dart';

class RecipeSearchDelegate extends SearchDelegate<String?> {
  final WidgetRef ref;
  RecipeSearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'Search recipes, categories';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear),
          tooltip: 'Clear',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final asyncResults = ref.watch(searchResultsProvider(query));
    final bookmarks = ref.watch(bookmarksProvider);
    return asyncResults.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No results'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: .78,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final r = items[index];
            final isBookmarked = bookmarks.contains(r.id);
            return Padding(
              padding: const EdgeInsets.all(6.0),
              child: RecipeSmallCard(
                recipe: r,
                saved: isBookmarked,
                onToggleSave: () =>
                    ref.read(bookmarkIdsNotifierProvider.notifier).toggle(r.id),
                height: 220,
                width: double.infinity,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const Center(child: Text('Error searching')),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('Type to search recipes'));
    }
    return buildResults(context);
  }
}
