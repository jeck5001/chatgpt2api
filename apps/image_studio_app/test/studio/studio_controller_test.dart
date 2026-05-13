import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/studio/studio_controller.dart';
import 'package:image_studio_app/studio/studio_models.dart';
import 'package:image_studio_app/studio/studio_repository.dart';

void main() {
  test('polling stops after turn reaches terminal state', () async {
    final repository = FakeStudioRepository();
    final controller = StudioController(repository);

    controller.replaceTurns([fakeTurn(status: StudioTurnStatus.running)]);
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

  test('load workspace creates missing project and conversation', () async {
    final repository = FakeStudioRepository();
    final controller = StudioController(repository);

    await controller.loadWorkspace();

    expect(controller.state.activeProject?.name, 'Untitled Project');
    expect(controller.state.activeConversation?.title, 'New image session');
    expect(repository.createdProjectName, 'Untitled Project');
  });
}

class FakeStudioRepository implements StudioRepositoryContract {
  bool failSubmit = false;
  String? createdProjectName;

  @override
  Future<List<StudioProject>> fetchProjects() async {
    return [];
  }

  @override
  Future<StudioProject> createProject(String name) async {
    createdProjectName = name;
    return StudioProject(
      id: 'project-1',
      name: name,
      ownerId: 'admin',
      archived: false,
      createdAt: DateTime.utc(2026, 5, 12),
      updatedAt: DateTime.utc(2026, 5, 12),
    );
  }

  @override
  Future<List<StudioConversation>> fetchConversations(String projectId) async {
    return [];
  }

  @override
  Future<StudioConversation> createConversation({
    required String projectId,
    required String title,
    String mode = 'generate',
  }) async {
    return StudioConversation(
      id: 'conversation-1',
      projectId: projectId,
      title: title,
      mode: StudioTurnMode.generate,
      updatedAt: DateTime.utc(2026, 5, 12),
    );
  }

  @override
  Future<List<StudioTurn>> fetchTurns(String conversationId) async {
    return [];
  }

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

  @override
  Future<List<StudioFavorite>> fetchFavorites() async {
    return [];
  }

  @override
  Future<StudioFavorite> favoriteImage({
    required String imagePath,
    String sourceTurnId = '',
  }) async {
    return StudioFavorite(
      id: 'favorite-1',
      imagePath: imagePath,
      sourceTurnId: sourceTurnId,
      createdAt: DateTime.utc(2026, 5, 12),
    );
  }

  @override
  Future<void> deleteFavorite(String favoriteId) async {}
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
