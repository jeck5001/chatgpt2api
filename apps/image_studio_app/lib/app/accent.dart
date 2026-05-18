import 'package:flutter/material.dart';

import 'tokens.dart';

/// Per-user accent option. Surfaces a small set of palettes so the
/// brand color can match the user's mood. `name` matches the value
/// serialized in [StudioPreferences].
enum KilnAccent {
  ember('ember'),
  sage('sage'),
  indigo('indigo'),
  slate('slate');

  const KilnAccent(this.name);
  final String name;

  static KilnAccent fromName(String? name) {
    switch (name) {
      case 'sage':
        return KilnAccent.sage;
      case 'indigo':
        return KilnAccent.indigo;
      case 'slate':
        return KilnAccent.slate;
      case 'ember':
      default:
        return KilnAccent.ember;
    }
  }
}

/// Accent-aware swap-in for the ember scale in [KilnColors]. Shade
/// names mirror `KilnColors.ember{300..700}` so call-sites read the
/// same way after they migrate.
@immutable
class KilnAccentPalette {
  const KilnAccentPalette({
    required this.shade300,
    required this.shade400,
    required this.shade500,
    required this.shade600,
    required this.shade700,
    required this.glow,
    required this.gradient,
  });

  final Color shade300;
  final Color shade400;
  final Color shade500;
  final Color shade600;
  final Color shade700;
  final Color glow;
  final Gradient gradient;

  static const ember = KilnAccentPalette(
    shade300: Color(0xFFF8D69A),
    shade400: Color(0xFFF2BE6B),
    shade500: Color(0xFFE8A84A),
    shade600: Color(0xFFC8743A),
    shade700: Color(0xFF8B3F2E),
    glow: Color(0x33E8A84A),
    gradient: KilnGradients.kiln,
  );

  static const sage = KilnAccentPalette(
    shade300: Color(0xFFB7D1B5),
    shade400: Color(0xFF8FB58D),
    shade500: Color(0xFF6B9B6A),
    shade600: Color(0xFF4F7950),
    shade700: Color(0xFF345537),
    glow: Color(0x336B9B6A),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [0.0, 0.35, 0.70, 1.0],
      colors: [
        Color(0xFF8FB58D),
        Color(0xFF6B9B6A),
        Color(0xFF4F7950),
        Color(0xFF345537),
      ],
    ),
  );

  static const indigo = KilnAccentPalette(
    shade300: Color(0xFFB4C2E8),
    shade400: Color(0xFF8AA0DA),
    shade500: Color(0xFF5A78C6),
    shade600: Color(0xFF3A569E),
    shade700: Color(0xFF2A3D72),
    glow: Color(0x335A78C6),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [0.0, 0.35, 0.70, 1.0],
      colors: [
        Color(0xFF8AA0DA),
        Color(0xFF5A78C6),
        Color(0xFF3A569E),
        Color(0xFF2A3D72),
      ],
    ),
  );

  static const slate = KilnAccentPalette(
    shade300: Color(0xFFC6CDD4),
    shade400: Color(0xFF9FAAB6),
    shade500: Color(0xFF738090),
    shade600: Color(0xFF54616F),
    shade700: Color(0xFF394451),
    glow: Color(0x33738090),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [0.0, 0.35, 0.70, 1.0],
      colors: [
        Color(0xFF9FAAB6),
        Color(0xFF738090),
        Color(0xFF54616F),
        Color(0xFF394451),
      ],
    ),
  );

  static KilnAccentPalette forAccent(KilnAccent accent) {
    switch (accent) {
      case KilnAccent.ember:
        return ember;
      case KilnAccent.sage:
        return sage;
      case KilnAccent.indigo:
        return indigo;
      case KilnAccent.slate:
        return slate;
    }
  }
}

/// Exposes the active accent palette to descendants. Widgets that
/// want to respect the user's accent preference look it up via
/// [KilnThemeScope.of] (auto-rebuilds when the palette changes).
///
/// Defaults to the ember palette when no scope is found, so widgets
/// rendered outside the studio (login, onboarding) keep the signature
/// warm tone.
class KilnThemeScope extends InheritedWidget {
  const KilnThemeScope({
    super.key,
    required this.palette,
    required super.child,
  });

  final KilnAccentPalette palette;

  static KilnAccentPalette of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<KilnThemeScope>();
    return scope?.palette ?? KilnAccentPalette.ember;
  }

  @override
  bool updateShouldNotify(KilnThemeScope oldWidget) =>
      palette != oldWidget.palette;
}
