import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppNetworkImage extends StatelessWidget {
  final String url;
  final double? height;
  final double? width;
  final BoxFit fit;
  final BorderRadius borderRadius;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    final placeholderColor = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest;

    if (url.isEmpty) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: placeholderColor,
          borderRadius: borderRadius,
        ),
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: url,
        height: height,
        width: width,
        fit: fit,
        placeholder: (context, _) =>
            Container(color: placeholderColor, height: height, width: width),
        errorWidget: (context, _, __) => Container(
          color: placeholderColor,
          height: height,
          width: width,
          child: const Icon(Icons.image_not_supported_outlined),
        ),
      ),
    );
  }
}
