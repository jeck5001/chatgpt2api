import 'package:flutter/material.dart';

import '../../app/tokens.dart';

/// A glowing dot that pulses gently — used to indicate "in progress"
/// states (running turn, key active, etc).
class EmberPulseDot extends StatefulWidget {
  const EmberPulseDot({
    super.key,
    this.size = 8,
    this.color = KilnColors.ember500,
    this.glowRadius = 12,
  });

  final double size;
  final Color color;
  final double glowRadius;

  @override
  State<EmberPulseDot> createState() => _EmberPulseDotState();
}

class _EmberPulseDotState extends State<EmberPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: KilnMotion.emberPulse,
      vsync: this,
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.15)
        .animate(CurvedAnimation(parent: _controller, curve: KilnMotion.easeInOut));
    _opacity = Tween<double>(begin: 0.45, end: 0.95)
        .animate(CurvedAnimation(parent: _controller, curve: KilnMotion.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.scale(
          scale: _scale.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: _opacity.value),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.6),
                  blurRadius: widget.glowRadius,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
