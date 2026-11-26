import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/recipes/data/recipe.dart';
import '../motion.dart';
import '../theme.dart';
import 'network_image.dart';
import 'skeletons.dart';

/// Hero tag shared by a recipe card and the detail header. [scope] keeps
/// tags unique when one recipe shows twice on a screen.
String recipeHeroTag(String id, String scope) => 'recipe-$scope-$id';

void openRecipe(BuildContext context, Recipe r, String scope) =>
    context.push('/recipe/${r.id}?h=$scope');

/// Image with the sized CDN URL for its box.
class RecipePhoto extends StatelessWidget {
  const RecipePhoto(
      {super.key, required this.recipe, this.borderRadius = BorderRadius.zero});
  final Recipe recipe;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth.isFinite ? c.maxWidth : 400.0;
      return AppNetworkImage(
        url: recipe.imageFor(w, dpr),
        width: double.infinity,
        height: double.infinity,
        cacheWidth: (w * dpr).round(),
        borderRadius: borderRadius,
      );
    });
  }
}

/// Grid card: rounded photo, title, time and category.
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.saved,
    required this.onToggleSave,
    this.heroScope = 'grid',
  });

  final Recipe recipe;
  final bool saved;
  final VoidCallback onToggleSave;
  final String heroScope;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final mins = formatMinutes(recipe.displayMinutes);

    return Pressable(
      onTap: () => openRecipe(context, recipe, heroScope),
      semanticLabel: recipe.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Hero(
                    tag: recipeHeroTag(recipe.id, heroScope),
                    child: RecipePhoto(
                        recipe: recipe,
                        borderRadius: BorderRadius.circular(22)),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: HeartButton(
                      saved: saved, onPressed: onToggleSave, size: 18),
                ),
                if (mins != null)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: _Pill(icon: Icons.schedule_rounded, label: mins),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            recipe.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
          ),
          if (recipe.category case final c?) ...[
            const SizedBox(height: 3),
            Text(c,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium?.copyWith(color: cs.primary)),
          ],
        ],
      ),
    );
  }
}

/// Large image-forward card for the Trending carousel.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.recipe,
    required this.saved,
    required this.onToggleSave,
    this.heroScope = 'feature',
  });

  final Recipe recipe;
  final bool saved;
  final VoidCallback onToggleSave;
  final String heroScope;

  @override
  Widget build(BuildContext context) {
    final mins = formatMinutes(recipe.displayMinutes);
    return Pressable(
      onTap: () => openRecipe(context, recipe, heroScope),
      semanticLabel: recipe.title,
      scale: 0.98,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: recipeHeroTag(recipe.id, heroScope),
              child: RecipePhoto(recipe: recipe),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.35, 1],
                  colors: [Colors.transparent, Color(0xCC000000)],
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: HeartButton(saved: saved, onPressed: onToggleSave),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (recipe.category case final c?)
                    Text(c.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: display(24, color: Colors.white)),
                  if (mins != null || recipe.servingsLabel != null) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, children: [
                      if (mins != null)
                        _Pill(icon: Icons.schedule_rounded, label: mins),
                      if (recipe.servingsLabel case final s?)
                        _Pill(icon: Icons.people_alt_outlined, label: s),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Sliver grid of [RecipeCard]s that fade in one after another.
class RecipeSliverGrid extends StatelessWidget {
  const RecipeSliverGrid({
    super.key,
    required this.items,
    required this.saved,
    required this.onToggleSave,
    this.heroScope = 'grid',
  });

  final List<Recipe> items;
  final Set<String> saved;
  final void Function(String id) onToggleSave;
  final String heroScope;

  @override
  Widget build(BuildContext context) {
    return SliverGrid.builder(
      gridDelegate: recipeGridDelegate(context),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final r = items[i];
        return FadeSlideIn(
          index: i,
          child: RecipeCard(
            recipe: r,
            saved: saved.contains(r.id),
            onToggleSave: () => onToggleSave(r.id),
            heroScope: heroScope,
          ),
        );
      },
    );
  }
}
