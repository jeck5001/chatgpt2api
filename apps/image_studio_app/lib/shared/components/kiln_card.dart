import 'package:flutter/material.dart';

import '../../app/tokens.dart';

/// The signature card used everywhere in Kiln.
///
/// A warm-dark surface with a hairline border, a soft subsurface gradient
/// overlay (alpha-only), and an optional ember glow rising from the bottom
/// edge — the "kiln heat" signature.
class KilnCard extends StatelessWidget {
  const KilnCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KilnSpacing.lg),
    this.emberGlow = false,
    this.borderColor,
    this.background,
    this.onTap,
    this.radius = KilnRadii.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool emberGlow;
  final Color? borderColor;
  final Color? background;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? KilnColors.hairline),
    );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Ink(
          decoration: ShapeDecoration(
            color: background ?? KilnColors.ink900,
            shape: shape,
            shadows: KilnShadows.card,
          ),
          child: Stack(
            children: [
              // Subtle alpha gradient overlay (top light → bottom shadow).
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: KilnGradients.cardSurface,
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  ),
                ),
              ),
              if (emberGlow)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 80,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: KilnGradients.emberGlowBottom,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(radius),
                          bottomRight: Radius.circular(radius),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}
