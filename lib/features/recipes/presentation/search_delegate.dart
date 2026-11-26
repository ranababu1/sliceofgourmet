import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// use a package import plus alias so the provider symbol always resolves
import 'package:sliceofgourmet/features/recipes/providers.dart' as p;

import '../../../core/widgets/recipe_card.dart';
import '../../../core/widgets/state_views.dart';

/// Searches the on-device catalog, so typing costs the site nothing.
class RecipeSearchDelegate extends SearchDelegate<String?> {
  @override
  String get searchFieldLabel => 'Search recipes';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final t = Theme.of(context);
    return t.copyWith(
      appBarTheme: t.appBarTheme.copyWith(backgroundColor: t.colorScheme.surface),
      inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            onPressed: () => query = '',
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Clear',
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: 'Back',
      );

  @override
  Widget buildResults(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final asyncResults = ref.watch(p.searchResultsProvider(query));
      final saved = ref.watch(p.bookmarksProvider);
      return asyncResults.when(
        data: (items) {
          if (items.isEmpty) {
            return const MessageView(
                message: 'No recipes match that. Try another word.',
                icon: Icons.search_off_rounded);
          }
          return CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              sliver: RecipeSliverGrid(
                items: items,
                saved: saved,
                heroScope: 'search',
                onToggleSave: (id) =>
                    ref.read(p.bookmarkIdsNotifierProvider.notifier).toggle(id),
              ),
            ),
          ]);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const MessageView(
            message: kOfflineMessage, icon: Icons.cloud_off_rounded),
      );
    });
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return Consumer(builder: (context, ref, _) {
        final cats = ref.watch(p.categoriesProvider).valueOrNull ?? const [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Popular', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in cats.take(10))
                ActionChip(
                  label: Text(c.name),
                  onPressed: () {
                    query = c.name;
                    showResults(context);
                  },
                ),
            ]),
          ],
        );
      });
    }
    return buildResults(context);
  }
}
