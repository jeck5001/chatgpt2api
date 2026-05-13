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
  });

  /// Headline. Anything inside curly braces "{like this}" is rendered in
  /// italic ember color, matching the design mockups.
  final String title;
  final String message;
  final String? accent;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KilnSpacing.xl,
          vertical: KilnSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLogo) ...[
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
