import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/shared/components/name_prompt_dialog.dart';

void main() {
  testWidgets('returns trimmed input when confirm is tapped', (tester) async {
    String? captured = 'pending';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  captured = await showNamePromptDialog(
                    context,
                    title: '新建项目',
                    hint: '项目名称',
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('新建项目'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  Untitled  ');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(captured, 'Untitled');
  });

  testWidgets('returns null when cancelled', (tester) async {
    String? captured = 'pending';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  captured = await showNamePromptDialog(context, title: '新建会话');
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(captured, isNull);
  });

  testWidgets('does not leave dependents when dismissed', (tester) async {
    // Regression guard: the previous inline-controller pattern could trigger
    // `_dependents.isEmpty` assertion failures during dialog tear-down.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showNamePromptDialog(context, title: '新建'),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
  });
}
