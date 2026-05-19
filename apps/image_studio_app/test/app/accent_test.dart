import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/app/accent.dart';

void main() {
  group('KilnAccent.fromName', () {
    test('maps known names', () {
      expect(KilnAccent.fromName('ember'), KilnAccent.ember);
      expect(KilnAccent.fromName('sage'), KilnAccent.sage);
      expect(KilnAccent.fromName('indigo'), KilnAccent.indigo);
      expect(KilnAccent.fromName('slate'), KilnAccent.slate);
    });

    test('falls back to ember for unknown or null', () {
      expect(KilnAccent.fromName(null), KilnAccent.ember);
      expect(KilnAccent.fromName(''), KilnAccent.ember);
      expect(KilnAccent.fromName('mystery'), KilnAccent.ember);
    });
  });

  group('KilnAccentPalette.forAccent', () {
    test('returns the matching palette', () {
      expect(
        KilnAccentPalette.forAccent(KilnAccent.ember),
        same(KilnAccentPalette.ember),
      );
      expect(
        KilnAccentPalette.forAccent(KilnAccent.sage),
        same(KilnAccentPalette.sage),
      );
      expect(
        KilnAccentPalette.forAccent(KilnAccent.indigo),
        same(KilnAccentPalette.indigo),
      );
      expect(
        KilnAccentPalette.forAccent(KilnAccent.slate),
        same(KilnAccentPalette.slate),
      );
    });
  });

  group('KilnThemeScope.of', () {
    testWidgets('returns ember when no scope is found', (tester) async {
      KilnAccentPalette? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = KilnThemeScope.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(captured, same(KilnAccentPalette.ember));
    });

    testWidgets('returns the active palette and rebuilds on change', (
      tester,
    ) async {
      final palettes = <KilnAccentPalette>[];
      Widget host(KilnAccentPalette palette) => MaterialApp(
        home: KilnThemeScope(
          palette: palette,
          child: Builder(
            builder: (context) {
              palettes.add(KilnThemeScope.of(context));
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpWidget(host(KilnAccentPalette.sage));
      expect(palettes.last, same(KilnAccentPalette.sage));

      await tester.pumpWidget(host(KilnAccentPalette.indigo));
      expect(palettes.last, same(KilnAccentPalette.indigo));
      expect(palettes.length, greaterThanOrEqualTo(2));
    });
  });
}
