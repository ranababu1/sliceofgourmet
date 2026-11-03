import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html;
import '../data/recipe.dart';
import '../providers.dart';
import '../../../core/widgets/network_image.dart';
import '../../../core/widgets/state_views.dart';

/// Turns post HTML into readable paragraphs, dropping the WPRM recipe card
/// (ingredients/instructions are shown separately) and scripts/styles.
String recipeBodyText(Recipe recipe) {
  final doc = html.parse(recipe.content);
  doc
      .querySelectorAll(
          '.wprm-recipe-container, .wprm-recipe, script, style, noscript')
      .forEach((e) => e.remove());
  final paragraphs = doc
      .querySelectorAll('p, h2, h3, h4, li')
      .map((e) => e.text.trim())
      .where((t) => t.isNotEmpty)
      .toList();
  var text = paragraphs.isNotEmpty
      ? paragraphs.join('\n\n')
      : (doc.body?.text.trim() ?? '');
  if (text.isEmpty) text = recipe.excerpt;
  return text.replaceAll('[…]', '').replaceAll('[&hellip;]', '').trim();
}

class RecipeDetailScreen extends ConsumerWidget {
  final String recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recipeByIdProvider(recipeId));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Recipe')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        appBar: AppBar(title: const Text('Recipe')),
        body: MessageView(
          message: kOfflineMessage,
          icon: Icons.cloud_off_rounded,
          onRetry: () => ref.invalidate(recipeByIdProvider(recipeId)),
        ),
      ),
      data: (recipe) => _RecipeDetailBody(recipe: recipe),
    );
  }
}

class _RecipeDetailBody extends ConsumerWidget {
  const _RecipeDetailBody({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBookmarked = ref.watch(bookmarksProvider).contains(recipe.id);
    final text = Theme.of(context).textTheme;
    final description = recipeBodyText(recipe);

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
            icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_outline),
            tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await ref
                .read(recipeRepositoryProvider)
                .fetchById(recipe.id, forceRefresh: true);
            ref.invalidate(recipeByIdProvider(recipe.id));
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Could not refresh, showing saved copy')));
            }
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            AppNetworkImage(
              url: recipe.imageUrl,
              height: 220,
              width: double.infinity,
              borderRadius: BorderRadius.circular(18),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                Chip(
                  label: Text(recipe.category ?? 'General'),
                  avatar: const Icon(Icons.category, size: 18),
                ),
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
                style: text.bodyLarge?.copyWith(fontFamily: 'Caveat', fontSize: 20),
              ),
            const SizedBox(height: 16),
            Text('Ingredients',
                style: text.titleLarge?.copyWith(fontFamily: 'Caveat', fontSize: 26)),
            const SizedBox(height: 8),
            if (recipe.ingredients.isEmpty)
              const Text('Ingredients not provided yet'),
            ...recipe.ingredients.map(
              (e) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline),
                title: Text(e,
                    style: const TextStyle(fontFamily: 'Caveat', fontSize: 20)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Instructions',
                style: text.titleLarge?.copyWith(fontFamily: 'Caveat', fontSize: 26)),
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
                        style:
                            const TextStyle(fontFamily: 'Caveat', fontSize: 20)),
                  ),
                ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
