import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../data/recipe.dart';
import '../../../core/widgets/network_image.dart';

class RecipeDetailScreen extends ConsumerWidget {
  final String recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(recipeRepositoryProvider);
    return FutureBuilder<Recipe>(
      future: repo.fetchById(recipeId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Recipe')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final recipe = snap.data!;
        final bookmarks = ref.watch(bookmarksProvider);
        final isBookmarked = bookmarks.contains(recipe.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(recipe.title),
            actions: [
              IconButton(
                onPressed: () => ref
                    .read(bookmarkIdsNotifierProvider.notifier)
                    .toggle(recipe.id),
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                ),
                tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              AppNetworkImage(
                url: recipe.imageUrl,
                height: 220,
                width: double.infinity,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    label: Text(recipe.category ?? 'General'),
                    avatar: const Icon(Icons.category, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Chip(
                    label: Text('${recipe.cookTimeMinutes} min'),
                    avatar: const Icon(Icons.timer_outlined, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                recipe.excerpt,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Ingredients',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...recipe.ingredients.map(
                (e) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(e),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Instructions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...recipe.instructions.asMap().entries.map(
                (e) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 12,
                    child: Text(
                      '${e.key + 1}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  title: Text(e.value),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
