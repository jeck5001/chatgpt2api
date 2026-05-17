import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/shared/components/purge_confirm_dialog.dart';

void main() {
  Future<void> openDialog(
    WidgetTester tester, {
    required Future<void> Function(bool? result) onClosed,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  final result = await showPurgeConfirmDialog(
                    context,
                    title: '删除会话',
                    message: '将永久删除',
                  );
                  await onClosed(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('returns false by default when confirming without checking',
      (tester) async {
    bool? captured;
    await openDialog(
      tester,
      onClosed: (value) async {
        captured = value;
      },
    );

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(captured, false);
  });

  testWidgets('returns true after toggling the purge checkbox',
      (tester) async {
    bool? captured;
    await openDialog(
      tester,
      onClosed: (value) async {
        captured = value;
      },
    );

    await tester.tap(find.text('同时从服务器删除已生成的图片'));
    await tester.pump();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(captured, true);
  });

  testWidgets('returns null when cancelled', (tester) async {
    bool? captured;
    var closeCount = 0;
    await openDialog(
      tester,
      onClosed: (value) async {
        captured = value;
        closeCount += 1;
      },
    );

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(closeCount, 1);
    expect(captured, isNull);
  });
}
