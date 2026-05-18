import 'package:flutter/material.dart';

import '../../app/accent.dart';
import '../../app/tokens.dart';
import '../../app/typography.dart';

/// Horizontal scrollable row of filter chips. Used at the top of Gallery,
/// inside the composer for the params row, etc.
class KilnChipBar extends StatelessWidget {
  const KilnChipBar({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.symmetric(
      horizontal: KilnSpacing.lg,
      vertical: KilnSpacing.xs,
    ),
    this.spacing = KilnSpacing.xs,
  });

  final List<KilnChipData> items;
  final EdgeInsetsGeometry padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            KilnChip(data: items[i]),
          ],
        ],
      ),
    );
  }
}

class KilnChipData {
  const KilnChipData({
    required this.label,
    this.icon,
    this.active = false,
    this.onTap,
    this.dot = false,
  });

  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback? onTap;
  final bool dot;
}

class KilnChip extends StatelessWidget {
  const KilnChip({super.key, required this.data});

  final KilnChipData data;

  @override
  Widget build(BuildContext context) {
    final palette = KilnThemeScope.of(context);
    final bg = data.active
        ? palette.shade500.withValues(alpha: 0.12)
        : KilnColors.ink800;
    final fg = data.active ? palette.shade400 : KilnColors.ink200;
    final border = data.active
        ? palette.shade500.withValues(alpha: 0.30)
        : KilnColors.hairlineStrong;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(KilnRadii.chip),
        onTap: data.onTap,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: KilnSpacing.sm),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(KilnRadii.chip),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data.dot) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: palette.shade500,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: KilnSpacing.xs2 + 2),
              ],
              if (data.icon != null) ...[
                Icon(data.icon, size: 12, color: fg),
                const SizedBox(width: KilnSpacing.xs2 + 2),
              ],
              Text(
                data.label,
                style: KilnTypography.chipMono.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
