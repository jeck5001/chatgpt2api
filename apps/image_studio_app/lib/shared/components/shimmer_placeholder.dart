import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/tokens.dart';

/// Warm shimmer placeholder for "generating" turns. Uses the ink palette
/// so it reads as "the image hasn't arrived yet" rather than "loading
/// data" — important for the kiln metaphor.
class ShimmerPlaceholder extends StatelessWidget {
  const ShimmerPlaceholder({
    super.key,
    this.borderRadius = 14,
    this.aspectRatio = 1.0,
  });

  final double borderRadius;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Shimmer.fromColors(
        baseColor: KilnColors.ink850,
        highlightColor: KilnColors.ink800,
        period: KilnMotion.shimmer,
        child: Container(
          decoration: BoxDecoration(
            color: KilnColors.ink850,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}
