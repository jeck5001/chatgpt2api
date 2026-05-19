import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/studio/studio_models.dart';
import 'package:image_studio_app/studio/turn_card.dart';

StudioTurn _turn({
  required StudioTurnStatus status,
  List<StudioResultImage> images = const [],
  String error = '',
}) {
  return StudioTurn(
    id: 'turn-1',
    conversationId: 'c-1',
    clientTaskId: 'task-1',
    taskId: 'task-1',
    mode: StudioTurnMode.generate,
    status: status,
    prompt: 'hello',
    model: 'gpt-image-2',
    size: '1024x1024',
    resultImages: images,
    error: error,
    updatedAt: DateTime.utc(2026, 5, 13),
  );
}

void main() {
  testWidgets('running turn rotates status phrases over time', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TurnCard(turn: _turn(status: StudioTurnStatus.running)),
        ),
      ),
    );

    expect(find.text('正在构图'), findsOneWidget);

    // _RunningStatusLine swaps phrases every 2400ms with a 320ms
    // AnimatedSwitcher fade. Advance past both so only the next phrase
    // is left in the tree.
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('正在渲染'), findsOneWidget);
  });

  testWidgets('successful image tile wraps Image.network in a Hero', (
    tester,
  ) async {
    final turn = _turn(
      status: StudioTurnStatus.success,
      images: [
        StudioResultImage(
          url: Uri.parse('http://test/images/2026/05/cat.png'),
          path: '2026/05/cat.png',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TurnCard(turn: turn)),
      ),
    );
    await tester.pump();

    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'studio-image:2026/05/cat.png');
  });

  testWidgets(
    'image tile without a path does not allocate a Hero (avoids tag collisions)',
    (tester) async {
      final turn = _turn(
        status: StudioTurnStatus.success,
        images: [
          StudioResultImage(
            url: Uri.parse('http://test/images/orphan.png'),
            path: '',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TurnCard(turn: turn)),
        ),
      );
      await tester.pump();

      expect(find.byType(Hero), findsNothing);
    },
  );
}
