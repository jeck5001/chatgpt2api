import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/studio/studio_controller.dart';
import 'package:image_studio_app/studio/studio_models.dart';
import 'package:image_studio_app/studio/studio_repository.dart';
import 'package:image_studio_app/studio/studio_session_screen.dart';

void main() {
  testWidgets('switching conversations updates the active create view', (
    tester,
  ) async {
    final repository = _FakeSessionRepository();
    final controller = StudioController(repository);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 900)),
          child: StudioSessionScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('cat'), findsOneWidget);
    expect(find.text('dog'), findsNothing);

    await tester.tap(find.text('Session Two'));
    await tester.pumpAndSettle();

    expect(find.text('dog'), findsOneWidget);
  });

  testWidgets('switching projects updates the active create view', (
    tester,
  ) async {
    final repository = _FakeSessionRepository();
    final controller = StudioController(repository);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 900)),
          child: StudioSessionScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('cat'), findsOneWidget);
    expect(find.text('dog'), findsNothing);

    await tester.tap(find.text('Project Two'));
    await tester.pumpAndSettle();

    expect(find.text('dog'), findsOneWidget);
  });
}

class _FakeSessionRepository implements StudioRepositoryContract {
  @override
  Future<List<StudioProject>> fetchProjects() async {
    return [
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
    ];
  }

  @override
  Future<StudioProject> createProject(String name) async {
    throw UnimplementedError();
  }

  @override
  Future<StudioProject> updateProject({
    required String projectId,
    String? name,
    bool? archived,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<StudioConversation>> fetchConversations(String projectId) async {
    if (projectId == 'project-2') {
      return [
        StudioConversation(
          id: 'conversation-2',
          projectId: projectId,
          title: 'Session Two',
          mode: StudioTurnMode.generate,
          updatedAt: DateTime.utc(2026, 5, 13),
        ),
      ];
    }
    return [
      StudioConversation(
        id: 'conversation-1',
        projectId: projectId,
        title: 'Session One',
        mode: StudioTurnMode.generate,
        updatedAt: DateTime.utc(2026, 5, 12),
      ),
      StudioConversation(
        id: 'conversation-2',
        projectId: projectId,
        title: 'Session Two',
        mode: StudioTurnMode.generate,
        updatedAt: DateTime.utc(2026, 5, 13),
      ),
    ];
  }

  @override
  Future<StudioConversation> createConversation({
    required String projectId,
    required String title,
    String mode = 'generate',
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<StudioTurn>> fetchTurns(String conversationId) async {
    if (conversationId == 'conversation-2') {
      return [
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
      ];
    }
    return [
      StudioTurn(
        id: 'turn-1',
        conversationId: 'conversation-1',
        clientTaskId: 'task-1',
        taskId: 'task-1',
        mode: StudioTurnMode.generate,
        prompt: 'cat',
        model: 'gpt-image-2',
        size: '1024x1024',
        resultImages: const [],
        status: StudioTurnStatus.success,
        error: '',
        updatedAt: DateTime.utc(2026, 5, 12),
      ),
    ];
  }

  @override
  Future<StudioTurn> createGenerationTurn({
    required String conversationId,
    required String clientTaskId,
    required String prompt,
    required String model,
    String? size,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<StudioTurn> syncTurn(String turnId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteConversation(
    String conversationId, {
    bool purge = false,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteTurn(String turnId, {bool purge = false}) async {
    throw UnimplementedError();
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
    throw UnimplementedError();
  }

  @override
  Future<StudioTurn> retryTurn({
    required String turnId,
    required String clientTaskId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<StudioFavorite>> fetchFavorites() async => [];

  @override
  Future<List<StudioAsset>> fetchLibraryAssets({
    String startDate = '',
    String endDate = '',
  }) async => const [];

  @override
  Future<List<String>> fetchImageTags() async => const [];

  @override
  Future<List<String>> updateImageTags({
    required String imagePath,
    required List<String> tags,
  }) async => tags;

  @override
  Future<void> deleteImages(List<String> imagePaths) async {}

  @override
  Future<Uint8List> downloadImagesZip(List<String> imagePaths) async {
    return Uint8List.fromList(const [80, 75, 3, 4]);
  }

  @override
  Future<StudioFavorite> favoriteImage({
    required String imagePath,
    String sourceTurnId = '',
  }) async {
    throw UnimplementedError();
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
    throw UnimplementedError();
  }

  @override
  Future<void> deletePromptTemplate(String templateId) async {}
}
