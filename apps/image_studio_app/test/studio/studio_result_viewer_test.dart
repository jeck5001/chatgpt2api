import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/studio/studio_image_saver.dart';
import 'package:image_studio_app/studio/studio_result_viewer.dart';

void main() {
  testWidgets('viewer shows save and share actions for a result image', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudioResultViewer(
          imageUrl: 'http://example.test/images/landscape.png',
          imagePath: '2026/05/landscape.png',
          promptText: 'beautiful landscape',
          imageSaver: StudioImageSaver(
            outputDirectoryProvider: () async => throw UnimplementedError(),
            bytesLoader: (_) async => throw UnimplementedError(),
          ),
          onShareImage: (imageSaver, imageUrl, fileName) async =>
              '/tmp/landscape.png',
        ),
      ),
    );

    expect(find.text('beautiful landscape'), findsWidgets);
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('分享'), findsOneWidget);
  });

  testWidgets('viewer labels variation action as parameter reuse', (
    tester,
  ) async {
    var reused = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StudioResultViewer(
          imageUrl: 'http://example.test/images/landscape.png',
          imagePath: '2026/05/landscape.png',
          promptText: 'beautiful landscape',
          model: 'gpt-image-2',
          size: '1024x1792',
          imageSaver: StudioImageSaver(
            outputDirectoryProvider: () async => throw UnimplementedError(),
            bytesLoader: (_) async => throw UnimplementedError(),
          ),
          onVariation: () => reused = true,
        ),
      ),
    );

    expect(find.text('复用'), findsOneWidget);
    expect(find.text('1024x1792'), findsOneWidget);

    await tester.tap(find.text('复用'));
    await tester.pump();

    expect(reused, isTrue);
  });

  testWidgets('tapping save shows a saved message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudioResultViewer(
          imageUrl: 'http://example.test/images/landscape.png',
          imagePath: '2026/05/landscape.png',
          imageSaver: StudioImageSaver(
            outputDirectoryProvider: () async => throw UnimplementedError(),
            bytesLoader: (_) async => throw UnimplementedError(),
          ),
          onSaveImage: (imageSaver, imageUrl, fileName) async =>
              '/tmp/landscape.png',
          onShareImage: (imageSaver, imageUrl, fileName) async =>
              '/tmp/landscape.png',
        ),
      ),
    );

    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.textContaining('Saved to'), findsOneWidget);
  });

  testWidgets('tapping share shows a shared message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudioResultViewer(
          imageUrl: 'http://example.test/images/landscape.png',
          imagePath: '2026/05/landscape.png',
          imageSaver: StudioImageSaver(
            outputDirectoryProvider: () async => throw UnimplementedError(),
            bytesLoader: (_) async => throw UnimplementedError(),
          ),
          onShareImage: (imageSaver, imageUrl, fileName) async =>
              '/tmp/landscape.png',
        ),
      ),
    );

    await tester.tap(find.text('分享'));
    await tester.pump();

    expect(find.textContaining('Shared'), findsOneWidget);
  });
}
