import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/studio/studio_result_viewer.dart';

void main() {
  testWidgets('viewer shows save and share actions for a result image', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StudioResultViewer(
          imageUrl: 'http://example.test/images/landscape.png',
          imagePath: '2026/05/landscape.png',
        ),
      ),
    );

    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });
}
