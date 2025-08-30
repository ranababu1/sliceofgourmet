import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/recipes/data/recipe.dart';
import 'network_image.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onBookmarkToggle;
  final bool isBookmarked;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onBookmarkToggle,
    required this.isBookmarked,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.pushNamed(
          'recipeDetail',
          pathParameters: {'id': recipe.id},
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppNetworkImage(
              url: recipe.imageUrl,
              height: 180,
              width: double.infinity,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text(
                recipe.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text('${recipe.cookTimeMinutes} min'),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.restaurant_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      recipe.category ?? 'General',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: onBookmarkToggle,
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                      color: isBookmarked
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
