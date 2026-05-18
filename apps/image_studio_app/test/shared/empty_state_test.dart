import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/shared/empty_state.dart';

void main() {
  testWidgets('renders provided icon in place of the kiln crest',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            title: '没找到',
            message: '换个关键词试试',
            icon: Icons.search_off_rounded,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
  });

  testWidgets('falls back to the kiln crest when no icon is provided',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(title: '图库', accent: '空空如也', message: 'm'),
        ),
      ),
    );

    expect(find.byIcon(Icons.search_off_rounded), findsNothing);
  });

  testWidgets('omits the crest entirely when showLogo is false',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            title: '简洁',
            message: 'm',
            showLogo: false,
          ),
        ),
      ),
    );

    // Title is still visible.
    expect(find.text('简洁'), findsOneWidget);
  });
}
