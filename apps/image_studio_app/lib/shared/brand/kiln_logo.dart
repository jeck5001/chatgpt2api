import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../app/typography.dart';

/// The Kiln brand mark — a small gradient square with an inner ember glow.
/// Pairs with the wordmark across onboarding, empty states, app icon, etc.
class KilnLogo extends StatelessWidget {
  const KilnLogo({super.key, this.size = 28, this.radius});

  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size * 0.28;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: KilnGradients.kiln,
              borderRadius: BorderRadius.circular(r),
              boxShadow: [
                BoxShadow(
                  color: KilnColors.ember600.withValues(alpha: 0.45),
                  blurRadius: size * 0.5,
                  offset: Offset(0, size * 0.15),
                ),
              ],
              border: Border.all(
                color: const Color(0x40FFE0B0),
                width: 1,
              ),
            ),
          ),
          // inner glow disc
          Positioned(
            top: size * 0.35,
            child: Container(
              width: size * 0.5,
              height: size * 0.5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r * 0.5),
                gradient: const RadialGradient(
                  center: Alignment(0, 0.3),
                  colors: [Color(0xCCFFE9C2), Color(0x00FFE9C2)],
                  stops: [0, 0.7],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Kiln wordmark — "Kiln" rendered in Fraunces with optical-size tuning.
/// Stays English even in the Chinese build (it is the brand identity).
class KilnWordmark extends StatelessWidget {
  const KilnWordmark({
    super.key,
    this.size = 28,
    this.color = KilnColors.ink100,
    this.weight = FontWeight.w500,
  });

  final double size;
  final Color color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Kiln',
      style: KilnTypography.display(
        size: size,
        weight: weight,
        color: color,
        letterSpacing: -size * 0.025,
        height: 1.0,
      ),
    );
  }
}
