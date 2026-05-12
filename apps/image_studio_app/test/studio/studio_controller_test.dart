import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/studio/studio_controller.dart';
import 'package:image_studio_app/studio/studio_models.dart';
import 'package:image_studio_app/studio/studio_repository.dart';

void main() {
  test('polling stops after turn reaches terminal state', () async {
    final repository = FakeStudioRepository();
    final controller = StudioController(repository);

    controller.replaceTurns([
      fakeTurn(status: StudioTurnStatus.running),
    ]);
    await controller.pollRunningTurnsOnce();

    expect(controller.state.turns.single.status, StudioTurnStatus.success);
    expect(controller.hasRunningTurns, isFalse);
  });

  test('draft is preserved when submit fails', () async {
    final repository = FakeStudioRepository()..failSubmit = true;
    final controller = StudioController(repository);

    await expectLater(
      controller.submitGeneration(
        conversationId: 'conversation-1',
        prompt: 'a red cabin',
      ),
      throwsA(isA<Exception>()),
    );

    expect(controller.state.promptDraft, 'a red cabin');
  });
}

class FakeStudioRepository implements StudioRepositoryContract {
  bool failSubmit = false;

  @override
  Future<StudioTurn> createGenerationTurn({
    required String conversationId,
    required String clientTaskId,
    required String prompt,
    required String model,
    String? size,
  }) async {
    if (failSubmit) {
      throw Exception('network down');
    }
    return fakeTurn(status: StudioTurnStatus.running);
  }

  @override
  Future<StudioTurn> syncTurn(String turnId) async {
    return fakeTurn(status: StudioTurnStatus.success);
  }
}

StudioTurn fakeTurn({required StudioTurnStatus status}) {
  return StudioTurn(
    id: 'turn-1',
    conversationId: 'conversation-1',
    clientTaskId: 'task-1',
    taskId: 'task-1',
    mode: StudioTurnMode.generate,
    prompt: 'cat',
    model: 'gpt-image-2',
    size: '1024x1024',
    resultImages: const [],
    status: status,
    error: '',
    updatedAt: DateTime.utc(2026, 5, 12),
  );
}
