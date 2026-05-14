import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../app/typography.dart';

/// Section header pattern shared across screens.
///
/// Two layouts:
///   • [SectionHeader.large] — top-of-page page title (mono kicker + display serif title).
///   • [SectionHeader.inline] — mono uppercase label used inside cards / between groups.
class SectionHeader extends StatelessWidget {
  const SectionHeader.large({
    super.key,
    required this.title,
    this.kicker,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      KilnSpacing.lg,
      KilnSpacing.xxl,
      KilnSpacing.lg,
      KilnSpacing.sm,
    ),
  }) : _inline = false;

  const SectionHeader.inline({
    super.key,
    required this.title,
    this.kicker,
    this.subtitle,
    this.trailing,
    this.padding = EdgeInsets.zero,
  }) : _inline = true;

  final String title;
  final String? kicker;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final bool _inline;

  @override
  Widget build(BuildContext context) {
    if (_inline) {
      return Padding(
        padding: padding,
        child: Row(
          children: [
            Text(title.toUpperCase(), style: KilnTypography.label),
            const SizedBox(width: KilnSpacing.sm),
            const Expanded(child: Divider(color: KilnColors.hairline)),
            ?trailing,
          ],
        ),
      );
    }
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kicker != null) ...[
                  Text(kicker!.toUpperCase(), style: KilnTypography.label),
                  const SizedBox(height: KilnSpacing.xs),
                ],
                Text(
                  title,
                  style: KilnTypography.display(
                    size: 32,
                    weight: FontWeight.w400,
                    height: 1.05,
                    letterSpacing: -0.6,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: KilnTypography.metaMono),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ignore_for_file: use_null_aware_elements
