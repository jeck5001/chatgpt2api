import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Kiln typography.
///
/// Three families are layered:
///   • Fraunces — Latin display serif with optical-size axis. Headlines, brand wordmark.
///   • Inter — Latin UI sans. Body, buttons, labels.
///   • JetBrains Mono — meta/technical text (model name, size, timestamps, seeds).
///
/// For Chinese rendering, Flutter's font fallback chain takes over automatically:
/// system fonts (PingFang on Apple, Source Han / Noto Sans CJK on others) handle
/// CJK glyphs gracefully. Google Fonts' Fraunces/Inter only ship Latin glyphs, so
/// Chinese characters naturally fall through to the platform default — this is the
/// intended behavior and matches the HTML mockup's font stack.
class KilnTypography {
  KilnTypography._();

  // --- Family accessors -------------------------------------------------

  static TextStyle display({
    double size = 32,
    FontWeight weight = FontWeight.w400,
    Color color = KilnColors.ink100,
    double? height,
    double letterSpacing = -0.4,
  }) {
    return GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height ?? 1.2,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.enable('ss01')],
    );
  }

  static TextStyle ui({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = KilnColors.ink100,
    double? height,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height ?? 1.5,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle mono({
    double size = 11,
    FontWeight weight = FontWeight.w400,
    Color color = KilnColors.ink400,
    double letterSpacing = 0.4,
    double? height,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height ?? 1.5,
    );
  }

  // --- Named scale ------------------------------------------------------

  static TextStyle get displayL =>
      display(size: 48, height: 1.05, letterSpacing: -1.0);
  static TextStyle get displayM =>
      display(size: 36, height: 1.1, letterSpacing: -0.8);
  static TextStyle get displayS =>
      display(size: 24, height: 1.25, letterSpacing: -0.4);

  static TextStyle get titleL =>
      ui(size: 20, weight: FontWeight.w600, height: 1.3, letterSpacing: -0.2);
  static TextStyle get titleM =>
      ui(size: 16, weight: FontWeight.w600, height: 1.4);

  static TextStyle get bodyL => ui(size: 16, height: 1.5);
  static TextStyle get bodyM => ui(size: 14, height: 1.55);
  static TextStyle get bodyS =>
      ui(size: 13, height: 1.5, color: KilnColors.ink300);

  /// Uppercased mono label — used for section headers, meta categories.
  static TextStyle get label => mono(
    size: 10,
    weight: FontWeight.w500,
    color: KilnColors.ink400,
    letterSpacing: 1.8,
  );

  /// Standard mono for inline meta (model, size, time).
  static TextStyle get metaMono =>
      mono(size: 11, color: KilnColors.ink400, letterSpacing: 0.4);

  /// Mono used inside chips and tags.
  static TextStyle get chipMono =>
      mono(size: 11, color: KilnColors.ink200, letterSpacing: 0.4);

  /// The "prompt" text that appears at the top of every turn — display-serif,
  /// slightly off-black, the visual anchor of each conversation entry.
  static TextStyle get prompt => display(
    size: 17,
    weight: FontWeight.w400,
    height: 1.45,
    letterSpacing: -0.1,
  );

  /// Italicized display for taglines, accents, "what do you want to make?" hero.
  static TextStyle get displayItalic => GoogleFonts.fraunces(
    fontSize: 24,
    fontWeight: FontWeight.w300,
    fontStyle: FontStyle.italic,
    color: KilnColors.ember400,
    height: 1.3,
    letterSpacing: -0.3,
  );

  // --- Material 3 TextTheme ---------------------------------------------

  /// Assembled TextTheme used by [buildImageStudioTheme]. Material widgets
  /// (AppBar, ListTile, etc.) pick up Fraunces for "display/headline" slots
  /// and Inter for everything else.
  static TextTheme get textTheme => TextTheme(
    displayLarge: displayL,
    displayMedium: displayM,
    displaySmall: displayS,
    headlineLarge: display(size: 28, height: 1.15, letterSpacing: -0.5),
    headlineMedium: display(size: 22, height: 1.2, letterSpacing: -0.3),
    headlineSmall: display(size: 18, height: 1.3, letterSpacing: -0.2),
    titleLarge: titleL,
    titleMedium: titleM,
    titleSmall: ui(size: 13, weight: FontWeight.w600),
    bodyLarge: bodyL,
    bodyMedium: bodyM,
    bodySmall: bodyS,
    labelLarge: ui(size: 14, weight: FontWeight.w600, letterSpacing: 0.1),
    labelMedium: ui(size: 12, weight: FontWeight.w500, letterSpacing: 0.2),
    labelSmall: label,
  );
}
