import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/recipes/data/recipe.dart';
import 'network_image.dart';

class RecipeSmallCard extends StatelessWidget {
  final Recipe recipe;
  final bool saved;
  final VoidCallback onToggleSave;
  final double height;
  final double? width;

  const RecipeSmallCard({
    super.key,
    required this.recipe,
    required this.saved,
    required this.onToggleSave,
    this.height = 190,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => context.push('/recipe/${recipe.id}'),
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(
                child: AppNetworkImage(url: recipe.imageUrl, fit: BoxFit.cover),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 36, 10, 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.60),
                      ],
                    ),
                  ),
                  child: Text(
                    recipe.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: InkWell(
                  onTap: onToggleSave,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      saved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 18,
                      color: saved ? Colors.red : Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
