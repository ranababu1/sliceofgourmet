import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Cached network image that decodes at the size it is shown, fades in,
/// and falls back to a tidy placeholder.
class AppNetworkImage extends StatelessWidget {
  final String url;
  final double? height;
  final double? width;
  final BoxFit fit;
  final BorderRadius borderRadius;

  /// Decode width in physical pixels. Saves memory on long lists.
  final int? cacheWidth;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.cacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget placeholder([IconData? icon]) => Container(
          height: height,
          width: width,
          color: cs.surfaceContainerHighest,
          alignment: Alignment.center,
          child: icon == null
              ? null
              : Icon(icon, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
        );

    final child = url.isEmpty
        ? placeholder(Icons.restaurant_menu_rounded)
        : CachedNetworkImage(
            imageUrl: url,
            height: height,
            width: width,
            fit: fit,
            memCacheWidth: cacheWidth,
            fadeInDuration: const Duration(milliseconds: 260),
            fadeOutDuration: Duration.zero,
            placeholder: (context, _) => placeholder(),
            errorWidget: (context, _, __) =>
                placeholder(Icons.image_not_supported_outlined),
          );
    if (borderRadius == BorderRadius.zero) return child;
    return ClipRRect(borderRadius: borderRadius, child: child);
  }
}
