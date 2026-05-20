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

  testWidgets('reusing a library asset fills the studio composer', (
    tester,
  ) async {
    final repository = _FakeSessionRepository(
      libraryAssets: [
        StudioAsset(
          path: '2026/05/19/orange.png',
          name: 'orange.png',
          date: '2026-05-19',
          sizeBytes: 4096,
          createdAt: DateTime.utc(2026, 5, 19),
          url: Uri.parse('http://localhost:8000/images/orange.png'),
          thumbnailUrl: Uri.parse(
            'http://localhost:8000/image-thumbnails/orange.png',
          ),
          prompt: 'orange product photo',
          model: 'gpt-image-1',
          sizeLabel: '1792x1024',
        ),
      ],
    );
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

    await tester.tap(find.byTooltip('复用参数'));
    await tester.pumpAndSettle();

    final fieldTexts = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller?.text ?? '')
        .toList(growable: false);
    expect(fieldTexts, contains('orange product photo'));
    expect(find.text('gpt-image-1'), findsAtLeastNWidgets(1));

    await tester.tap(find.byKey(const ValueKey('composer-submit')));
    await tester.pump();

    expect(repository.lastGenerationPrompt, 'orange product photo');
    expect(repository.lastGenerationModel, 'gpt-image-1');
    expect(repository.lastGenerationSize, '1792x1024');
  });
}

class _FakeSessionRepository implements StudioRepositoryContract {
  _FakeSessionRepository({this.libraryAssets = const []});

  final List<StudioAsset> libraryAssets;
  String? lastGenerationPrompt;
  String? lastGenerationModel;
  String? lastGenerationSize;

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
    lastGenerationPrompt = prompt;
    lastGenerationModel = model;
    lastGenerationSize = size;
    return StudioTurn(
      id: 'turn-generated',
      conversationId: conversationId,
      clientTaskId: clientTaskId,
      taskId: 'task-generated',
      mode: StudioTurnMode.generate,
      prompt: prompt,
      model: model,
      size: size,
      resultImages: const [],
      status: StudioTurnStatus.success,
      error: '',
      updatedAt: DateTime.utc(2026, 5, 20),
    );
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
  Future<StudioTurn> createInpaintTurn({
    required String conversationId,
    required String clientTaskId,
    required String prompt,
    required String model,
    String? size,
    required StudioEditImage image,
    required StudioEditImage mask,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String> draftPromptFromImage({
    required List<StudioEditImage> images,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String> optimizePrompt(String prompt) async {
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
  }) async => libraryAssets;

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
  Future<List<StudioRecipe>> fetchRecipes() async => const [];

  @override
  Future<List<StudioRecipe>> fetchPromptHubRecipes() async => const [];

  @override
  Future<StudioRecipe> createRecipe({
    required String name,
    required String prompt,
    required String model,
    String? size,
    String sourceImagePath = '',
    String sourceTurnId = '',
    String projectId = '',
    List<String> tags = const [],
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<StudioRecipe> updateRecipeSharing({
    required String recipeId,
    required bool shared,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<StudioRecipe> clonePromptHubRecipe(String recipeId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteRecipe(String recipeId) async {}

  @override
  Future<List<StudioConsistencyProfile>> fetchConsistencyProfiles() async =>
      const [];

  @override
  Future<StudioConsistencyProfile> createConsistencyProfile({
    required String name,
    required StudioConsistencyProfileKind kind,
    required String guidance,
    String referenceImagePath = '',
    List<String> tags = const [],
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<StudioConsistencyProfile> updateConsistencyProfile({
    required String profileId,
    String? name,
    StudioConsistencyProfileKind? kind,
    String? guidance,
    String? referenceImagePath,
    List<String>? tags,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteConsistencyProfile(String profileId) async {}

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
