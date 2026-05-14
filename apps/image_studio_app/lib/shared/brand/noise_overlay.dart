import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Subtle paper-grain noise overlay. Stack on top of any container to break
/// up flat dark surfaces — this is the trick that makes Kiln feel "printed"
/// instead of "synthetic".
///
/// Opacity defaults to 4% which is invisible on bright displays but adds
/// just enough texture on OLED screens.
class NoiseOverlay extends StatelessWidget {
  const NoiseOverlay({super.key, this.opacity = 0.04, this.tileSize = 220});

  final double opacity;
  final double tileSize;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(
          painter: _NoisePainter(tileSize: tileSize),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  _NoisePainter({required this.tileSize});

  final double tileSize;
  static final _rng = math.Random(42);
  // Pre-baked dot positions (small set, repeated across the canvas).
  // Using a stable RNG seed keeps the texture identical across rebuilds.
  static final List<Offset> _samples = List.generate(
    220,
    (_) => Offset(_rng.nextDouble(), _rng.nextDouble()),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFF4ECDD);
    final tilesX = (size.width / tileSize).ceil();
    final tilesY = (size.height / tileSize).ceil();
    for (var ty = 0; ty < tilesY; ty++) {
      for (var tx = 0; tx < tilesX; tx++) {
        for (final s in _samples) {
          final dx = tx * tileSize + s.dx * tileSize;
          final dy = ty * tileSize + s.dy * tileSize;
          canvas.drawCircle(Offset(dx, dy), 0.5, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) =>
      oldDelegate.tileSize != tileSize;
}
