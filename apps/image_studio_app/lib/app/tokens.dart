import 'package:flutter/material.dart';

/// Kiln design tokens.
///
/// All colors, gradients, radii, spacing, shadows, and motion constants live here.
/// Pages and widgets should pull from these classes rather than hard-coding values.
class KilnColors {
  KilnColors._();

  // Surface (ink scale — warm-dark, never pure black)
  static const ink950 = Color(0xFF0A0807);
  static const ink900 = Color(0xFF14110D);
  static const ink850 = Color(0xFF1A1611);
  static const ink800 = Color(0xFF1F1A14);
  static const ink700 = Color(0xFF2C251C);
  static const ink600 = Color(0xFF4A4034);
  static const ink500 = Color(0xFF6B5E4D);
  static const ink400 = Color(0xFF8F8270);
  static const ink300 = Color(0xFFB8AC97);
  static const ink200 = Color(0xFFD9CFBA);
  static const ink100 = Color(0xFFF4ECDD); // primary text — warm white

  // Brand (ember scale — the kiln's heat)
  static const ember300 = Color(0xFFF8D69A);
  static const ember400 = Color(0xFFF2BE6B);
  static const ember500 = Color(0xFFE8A84A); // primary brand
  static const ember600 = Color(0xFFC8743A);
  static const ember700 = Color(0xFF8B3F2E);
  static const emberGlow = Color(0x33E8A84A); // ~20% alpha for focus rings

  // Semantic (low saturation to avoid feeling cheap)
  static const success = Color(0xFF6FBF8B);
  static const warn = Color(0xFFE8B85A);
  static const danger = Color(0xFFE07A6B);
  static const info = Color(0xFF7BAACF);

  // Translucent overlays (for borders, dividers, glass effects)
  static const hairline = Color(0x0FF4ECDD); // ~6% warm white
  static const hairlineStrong = Color(0x1FF4ECDD); // ~12% warm white
  static const overlayWeak = Color(0x0DF4ECDD); // ~5%
  static const overlayStrong = Color(0x14F4ECDD); // ~8%
}

class KilnGradients {
  KilnGradients._();

  /// The signature gradient — used on the primary CTA, brand mark, and warm focal points.
  static const kiln = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.35, 0.70, 1.0],
    colors: [
      Color(0xFFF2BE6B),
      Color(0xFFE8A84A),
      Color(0xFFC8743A),
      Color(0xFF8B3F2E),
    ],
  );

  /// Subtle ember glow used at the bottom edge of turn cards — the "kiln heat" signature.
  static const emberGlowBottom = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0x1AE8A84A), Color(0x00E8A84A)],
  );

  /// Card surface gradient — very subtle top-light / bottom-shadow.
  static const cardSurface = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x04FFFFFF), Color(0x26000000)],
  );

  /// Overlay applied to project cover cards so the title remains legible.
  static const coverOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.30, 1.0],
    colors: [Color(0x00000000), Color(0xD914080C)],
  );
}

class KilnSpacing {
  KilnSpacing._();
  static const xs2 = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

class KilnRadii {
  KilnRadii._();
  static const sm = 8.0;
  static const md = 12.0;
  static const button = 14.0;
  static const input = 16.0;
  static const card = 20.0;
  static const xl = 24.0;
  static const chip = 999.0;
}

class KilnShadows {
  KilnShadows._();

  static const card = <BoxShadow>[
    BoxShadow(
      color: Color(0x80000000),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  static const float = <BoxShadow>[
    BoxShadow(
      color: Color(0x99000000),
      offset: Offset(0, 16),
      blurRadius: 48,
    ),
  ];

  /// Glow under the primary CTA — feels like a warm coal under glass.
  static const cta = <BoxShadow>[
    BoxShadow(
      color: Color(0x59C8743A),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];
}

class KilnMotion {
  KilnMotion._();
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);
  static const shimmer = Duration(milliseconds: 1800);
  static const emberPulse = Duration(milliseconds: 2400);

  static const easeOut = Curves.easeOutCubic;
  static const easeInOut = Curves.easeInOutCubic;
  static const spring = Curves.easeOutBack;
}
