import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerBox extends StatelessWidget {
  final double height;
  final double width;
  final BorderRadius borderRadius;
  const ShimmerBox({
    super.key,
    required this.height,
    required this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.black12,
      highlightColor: Colors.black26,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

class ShimmerCardLarge extends StatelessWidget {
  const ShimmerCardLarge({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(
      height: 260,
      width: double.infinity,
      borderRadius: BorderRadius.circular(22),
    );
  }
}

class ShimmerTileSmall extends StatelessWidget {
  const ShimmerTileSmall({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(
      height: 170,
      width: 200,
      borderRadius: BorderRadius.circular(18),
    );
  }
}
