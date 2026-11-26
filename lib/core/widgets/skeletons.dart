import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../motion.dart';

/// Shimmering placeholder block in the theme's surface colours.
class ShimmerBox extends StatelessWidget {
  final double? height;
  final double? width;
  final BorderRadius borderRadius;
  const ShimmerBox({
    super.key,
    this.height,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final box = Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
          color: cs.surfaceContainerHighest, borderRadius: borderRadius),
    );
    if (reduceMotion(context)) return box;
    return Shimmer.fromColors(
      baseColor: cs.surfaceContainerHighest,
      highlightColor: cs.surfaceContainerLowest,
      period: const Duration(milliseconds: 1400),
      child: box,
    );
  }
}

class ShimmerCardLarge extends StatelessWidget {
  const ShimmerCardLarge({super.key});

  @override
  Widget build(BuildContext context) => const ShimmerBox(
      height: 300,
      width: double.infinity,
      borderRadius: BorderRadius.all(Radius.circular(28)));
}

/// Grid card skeleton: image block plus two text lines.
class ShimmerRecipeCard extends StatelessWidget {
  const ShimmerRecipeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
            child: ShimmerBox(
                width: double.infinity,
                borderRadius: BorderRadius.all(Radius.circular(22)))),
        SizedBox(height: 10),
        ShimmerBox(height: 14, width: 120),
        SizedBox(height: 6),
        ShimmerBox(height: 12, width: 70),
      ],
    );
  }
}

/// A grid of [ShimmerRecipeCard]s as a sliver.
class ShimmerRecipeGrid extends StatelessWidget {
  const ShimmerRecipeGrid({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return SliverGrid.builder(
      gridDelegate: recipeGridDelegate(context),
      itemCount: count,
      itemBuilder: (_, __) => const ShimmerRecipeCard(),
    );
  }
}

/// Two columns on phones, more on tablets.
SliverGridDelegate recipeGridDelegate(BuildContext context) =>
    const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 240,
      mainAxisSpacing: 18,
      crossAxisSpacing: 14,
      childAspectRatio: 0.70,
    );
