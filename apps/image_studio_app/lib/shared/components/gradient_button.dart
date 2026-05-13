import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../app/typography.dart';

/// Primary call-to-action button wrapped in the signature kiln gradient
/// with a warm shadow. Use sparingly — it is the strongest visual hit
/// in the design system.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.height = 48,
    this.expand = false,
    this.borderRadius = KilnRadii.button,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  final bool expand;
  final double borderRadius;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final inner = AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: KilnMotion.fast,
      curve: KilnMotion.easeOut,
      child: AnimatedOpacity(
        duration: KilnMotion.base,
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: KilnGradients.kiln,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: enabled ? KilnShadows.cta : null,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: KilnSpacing.xl),
          child: Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 16, color: const Color(0xFF1A0E04)),
                const SizedBox(width: KilnSpacing.xs),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  style: KilnTypography.ui(
                    size: 14,
                    weight: FontWeight.w600,
                    color: const Color(0xFF1A0E04),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: widget.expand
          ? SizedBox(width: double.infinity, child: inner)
          : inner,
    );
  }
}
