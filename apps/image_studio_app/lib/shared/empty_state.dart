import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../app/typography.dart';
import 'brand/kiln_logo.dart';

/// Empty-state pattern shared across screens. Replaces the previous
/// minimalist version with a branded crest + Fraunces title + optional
/// italic accent word.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.accent,
    this.showLogo = true,
    this.icon,
  });

  /// Headline. Anything inside curly braces "{like this}" is rendered in
  /// italic ember color, matching the design mockups.
  final String title;
  final String message;
  final String? accent;
  final bool showLogo;

  /// Context-specific glyph rendered in place of the kiln crest. Lets
  /// each empty state feel tailored (search → magnifier, library →
  /// collections, etc.) without losing the warm tone.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final showCrest = showLogo && icon == null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KilnSpacing.xl,
          vertical: KilnSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              _GlyphHalo(icon: icon!),
              const SizedBox(height: KilnSpacing.xl),
            ] else if (showCrest) ...[
              const KilnLogo(size: 64),
              const SizedBox(height: KilnSpacing.xl),
            ],
            _buildTitle(),
            const SizedBox(height: KilnSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: KilnTypography.bodyM.copyWith(
                color: KilnColors.ink400,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    if (accent == null) {
      return Text(
        title,
        textAlign: TextAlign.center,
        style: KilnTypography.display(
          size: 22,
          weight: FontWeight.w400,
          height: 1.3,
        ),
      );
    }
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: title,
            style: KilnTypography.display(
              size: 22,
              weight: FontWeight.w400,
              height: 1.3,
            ),
          ),
          const TextSpan(text: ' '),
          TextSpan(
            text: accent,
            style: KilnTypography.displayItalic.copyWith(fontSize: 22),
          ),
        ],
      ),
    );
  }
}

class _GlyphHalo extends StatelessWidget {
  const _GlyphHalo({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: KilnColors.ink900,
        border: Border.all(color: KilnColors.hairlineStrong, width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x29E8A84A), blurRadius: 22, spreadRadius: 0),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 28, color: KilnColors.ember400),
    );
  }
}
