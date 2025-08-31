import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html;
import '../providers.dart';
import '../../../core/widgets/network_image.dart';

class RecipeDetailScreen extends ConsumerWidget {
  final String recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  String _stripHtml(String htmlSource) {
    final doc = html.parse(htmlSource);
    final text = doc.body?.text ?? htmlSource;
    return text.replaceAll('[…]', '').replaceAll('[&hellip;]', '').trim();
  }

  String _descriptionFrom(dynamic recipe) {
    try {
      final dyn = recipe as dynamic;
      final contentHtml = dyn.contentHtml as String?;
      if (contentHtml != null && contentHtml.isNotEmpty) {
        return _stripHtml(contentHtml);
      }
    } catch (_) {
      // ignore, fall back to excerpt
    }
    return _stripHtml(recipe.excerpt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(recipeRepositoryProvider);
    return FutureBuilder<dynamic>(
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

        final text = Theme.of(context).textTheme;
        final description = _descriptionFrom(recipe);

        return Scaffold(
          appBar: AppBar(
            title: SizedBox(
              height: kToolbarHeight - 16,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(recipe.title, softWrap: false),
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => ref
                    .read(bookmarkIdsNotifierProvider.notifier)
                    .toggle(recipe.id),
                icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_outline),
                tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
              )
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              AppNetworkImage(
                url: recipe.imageUrl,
                height: 220,
                width: double.infinity,
                borderRadius: BorderRadius.circular(18),
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
              if (description.isNotEmpty)
                Text(
                  description,
                  style: text.bodyLarge
                      ?.copyWith(fontFamily: 'Caveat', fontSize: 20),
                ),
              const SizedBox(height: 16),
              Text('Ingredients',
                  style: text.titleLarge
                      ?.copyWith(fontFamily: 'Caveat', fontSize: 26)),
              const SizedBox(height: 8),
              if (recipe.ingredients.isEmpty)
                const Text('Ingredients not provided yet'),
              ...recipe.ingredients.map(
                (e) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(e,
                      style:
                          const TextStyle(fontFamily: 'Caveat', fontSize: 20)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Instructions',
                  style: text.titleLarge
                      ?.copyWith(fontFamily: 'Caveat', fontSize: 26)),
              const SizedBox(height: 8),
              if (recipe.instructions.isEmpty)
                const Text('Instructions not provided yet'),
              ...recipe.instructions.asMap().entries.map(
                    (e) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 12,
                        child: Text('${e.key + 1}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      title: Text(e.value,
                          style: const TextStyle(
                              fontFamily: 'Caveat', fontSize: 20)),
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
