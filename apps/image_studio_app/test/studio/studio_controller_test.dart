import 'dart:typed_data';

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

  test(
    'failed syncTurn for one turn does not block the rest from progressing',
    () async {
      final repository = FakeStudioRepository()
        ..syncOverrides = {
          'turn-stale': (_) async => throw Exception('task expired'),
        };
      final controller = StudioController(repository);

      controller.replaceTurns([
        fakeTurn(id: 'turn-stale', status: StudioTurnStatus.running),
        fakeTurn(id: 'turn-fresh', status: StudioTurnStatus.running),
      ]);

      await controller.pollRunningTurnsOnce();

      final byId = {for (final t in controller.state.turns) t.id: t};
      expect(byId['turn-stale']!.status, StudioTurnStatus.running);
      expect(byId['turn-fresh']!.status, StudioTurnStatus.success);
    },
  );

  test('Timer-based polling settles a running turn into success', () async {
    final repository = FakeStudioRepository();
    final controller = StudioController(
      repository,
      pollInterval: const Duration(milliseconds: 20),
    );

    await controller.submitGeneration(
      conversationId: 'conversation-1',
      prompt: 'a glowing kiln',
    );
    expect(controller.state.turns.single.status, StudioTurnStatus.running);

    // Wait long enough for the internal Timer to fire and sync the turn.
    for (var i = 0; i < 20 && controller.hasRunningTurns; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }

    expect(controller.state.turns.single.status, StudioTurnStatus.success);
    expect(controller.hasRunningTurns, isFalse);
  });

  test('submitEdit adds the running turn and polls until success', () async {
    final repository = FakeStudioRepository();
    final controller = StudioController(
      repository,
      pollInterval: const Duration(milliseconds: 20),
    );

    await controller.submitEdit(
      conversationId: 'conversation-1',
      prompt: 'paint this castle in the snow',
      images: [
        StudioEditImage(
          bytes: Uint8List.fromList(const [1, 2, 3, 4]),
          filename: 'castle.png',
          contentType: 'image/png',
        ),
      ],
    );
    expect(controller.state.turns.single.status, StudioTurnStatus.running);

    for (var i = 0; i < 20 && controller.hasRunningTurns; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }

    expect(controller.state.turns.single.status, StudioTurnStatus.success);
    expect(repository.lastEditImages, 1);
  });

  test(
    'submitEdit rejects an empty image list before hitting the API',
    () async {
      final repository = FakeStudioRepository();
      final controller = StudioController(repository);

      await expectLater(
        controller.submitEdit(
          conversationId: 'conversation-1',
          prompt: 'paint without references',
          images: const [],
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(repository.lastEditImages, isNull);
    },
  );

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

  test(
    'load workspace keeps available project and conversation lists',
    () async {
      final repository = FakeStudioRepository()
        ..projects = [
          StudioProject(
            id: 'project-1',
            name: 'Project One',
            ownerId: 'admin',
            archived: false,
            createdAt: DateTime.utc(2026, 5, 12),
            updatedAt: DateTime.utc(2026, 5, 12),
          ),
        ]
        ..conversationsByProject = {
          'project-1': [
            StudioConversation(
              id: 'conversation-1',
              projectId: 'project-1',
              title: 'Session One',
              mode: StudioTurnMode.generate,
              updatedAt: DateTime.utc(2026, 5, 12),
            ),
          ],
        };
      final controller = StudioController(repository);

      await controller.loadWorkspace();

      expect(controller.state.projects.single.name, 'Project One');
      expect(controller.state.conversations.single.title, 'Session One');
    },
  );

  test('selectConversation loads turns for the chosen conversation', () async {
    final repository = FakeStudioRepository()
      ..projects = [
        StudioProject(
          id: 'project-1',
          name: 'Project One',
          ownerId: 'admin',
          archived: false,
          createdAt: DateTime.utc(2026, 5, 12),
          updatedAt: DateTime.utc(2026, 5, 12),
        ),
      ]
      ..conversationsByProject = {
        'project-1': [
          StudioConversation(
            id: 'conversation-1',
            projectId: 'project-1',
            title: 'Session One',
            mode: StudioTurnMode.generate,
            updatedAt: DateTime.utc(2026, 5, 12),
          ),
          StudioConversation(
            id: 'conversation-2',
            projectId: 'project-1',
            title: 'Session Two',
            mode: StudioTurnMode.generate,
            updatedAt: DateTime.utc(2026, 5, 13),
          ),
        ],
      }
      ..turnsByConversation = {
        'conversation-1': [fakeTurn(status: StudioTurnStatus.success)],
        'conversation-2': [
          StudioTurn(
            id: 'turn-2',
            conversationId: 'conversation-2',
            clientTaskId: 'task-2',
            taskId: 'task-2',
            mode: StudioTurnMode.generate,
            prompt: 'dog',
            model: 'gpt-image-2',
            size: '1024x1024',
            resultImages: const [],
            status: StudioTurnStatus.success,
            error: '',
            updatedAt: DateTime.utc(2026, 5, 13),
          ),
        ],
      };
    final controller = StudioController(repository);

    await controller.loadWorkspace();
    await controller.selectConversation('conversation-2');

    expect(controller.state.activeConversation?.id, 'conversation-2');
    expect(controller.state.turns.single.prompt, 'dog');
  });

  test(
    'selectProject switches conversations and loads the first turn list',
    () async {
      final repository = FakeStudioRepository()
        ..projects = [
          StudioProject(
            id: 'project-1',
            name: 'Project One',
            ownerId: 'admin',
            archived: false,
            createdAt: DateTime.utc(2026, 5, 12),
            updatedAt: DateTime.utc(2026, 5, 12),
          ),
          StudioProject(
            id: 'project-2',
            name: 'Project Two',
            ownerId: 'admin',
            archived: false,
            createdAt: DateTime.utc(2026, 5, 13),
            updatedAt: DateTime.utc(2026, 5, 13),
          ),
        ]
        ..conversationsByProject = {
          'project-1': [
            StudioConversation(
              id: 'conversation-1',
              projectId: 'project-1',
              title: 'Session One',
              mode: StudioTurnMode.generate,
              updatedAt: DateTime.utc(2026, 5, 12),
            ),
          ],
          'project-2': [
            StudioConversation(
              id: 'conversation-2',
              projectId: 'project-2',
              title: 'Session Two',
              mode: StudioTurnMode.generate,
              updatedAt: DateTime.utc(2026, 5, 13),
            ),
          ],
        }
        ..turnsByConversation = {
          'conversation-1': [fakeTurn(status: StudioTurnStatus.success)],
          'conversation-2': [
            StudioTurn(
              id: 'turn-2',
              conversationId: 'conversation-2',
              clientTaskId: 'task-2',
              taskId: 'task-2',
              mode: StudioTurnMode.generate,
              prompt: 'dog',
              model: 'gpt-image-2',
              size: '1024x1024',
              resultImages: const [],
              status: StudioTurnStatus.success,
              error: '',
              updatedAt: DateTime.utc(2026, 5, 13),
            ),
          ],
        };
      final controller = StudioController(repository);

      await controller.loadWorkspace();
      await controller.selectProject('project-2');

      expect(controller.state.activeProject?.id, 'project-2');
      expect(controller.state.activeConversation?.id, 'conversation-2');
      expect(controller.state.turns.single.prompt, 'dog');
    },
  );
}

class FakeStudioRepository implements StudioRepositoryContract {
  bool failSubmit = false;
  String? createdProjectName;
  int? lastEditImages;
  List<StudioProject> projects = [];
  Map<String, List<StudioConversation>> conversationsByProject = {};
  Map<String, List<StudioTurn>> turnsByConversation = {};
  Map<String, Future<StudioTurn> Function(String)> syncOverrides = const {};

  @override
  Future<List<StudioProject>> fetchProjects() async {
    return projects;
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
    return conversationsByProject[projectId] ?? [];
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
    return turnsByConversation[conversationId] ?? [];
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
  Future<StudioTurn> createEditTurn({
    required String conversationId,
    required String clientTaskId,
    required String prompt,
    required String model,
    String? size,
    required List<StudioEditImage> images,
  }) async {
    if (failSubmit) {
      throw Exception('network down');
    }
    lastEditImages = images.length;
    return fakeTurn(status: StudioTurnStatus.running);
  }

  @override
  Future<StudioTurn> syncTurn(String turnId) async {
    final override = syncOverrides[turnId];
    if (override != null) {
      return override(turnId);
    }
    return fakeTurn(id: turnId, status: StudioTurnStatus.success);
  }

  @override
  Future<StudioTurn> retryTurn({
    required String turnId,
    required String clientTaskId,
  }) async {
    if (failSubmit) {
      throw Exception('network down');
    }
    return fakeTurn(id: turnId, status: StudioTurnStatus.running);
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

  @override
  Future<List<StudioPromptTemplate>> fetchPromptTemplates() async => const [];

  @override
  Future<StudioPromptTemplate> createPromptTemplate({
    required String name,
    required String category,
    required String content,
  }) async {
    return StudioPromptTemplate(
      id: 'template-1',
      name: name,
      category: category,
      content: content,
      builtin: false,
      ownerId: 'me',
      updatedAt: DateTime.utc(2026, 5, 12),
    );
  }

  @override
  Future<void> deletePromptTemplate(String templateId) async {}
}

StudioTurn fakeTurn({String id = 'turn-1', required StudioTurnStatus status}) {
  return StudioTurn(
    id: id,
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
