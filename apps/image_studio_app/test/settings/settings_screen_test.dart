import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/settings/settings_screen.dart';

void main() {
  testWidgets('tapping the dead spots fires the injected callbacks', (
    tester,
  ) async {
    // Give the test viewport enough height to render the full Settings
    // sliver list without scrolling — the page is tall enough that the
    // export button sits below the default 800x600 surface otherwise.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var exportCalls = 0;
    var githubCalls = 0;
    var feedbackCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          onExportFavorites: () async => exportCalls += 1,
          onTapGithub: () async => githubCalls += 1,
          onTapFeedback: () async => feedbackCalls += 1,
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ElevatedButton, '导出收藏'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GitHub 源码'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('反馈意见'));
    await tester.pumpAndSettle();

    expect(exportCalls, 1);
    expect(githubCalls, 1);
    expect(feedbackCalls, 1);
  });
}
