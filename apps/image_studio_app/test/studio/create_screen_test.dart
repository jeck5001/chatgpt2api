import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/studio/create_screen.dart';
import 'package:image_studio_app/studio/studio_controller.dart';
import 'package:image_studio_app/studio/studio_models.dart';
import 'package:image_studio_app/studio/studio_repository.dart';

const _submitKey = ValueKey('composer-submit');

bool _submitDisabled(WidgetTester tester) {
  final widget = tester.widget<InkWell>(
    find.descendant(of: find.byKey(_submitKey), matching: find.byType(InkWell)),
  );
  return widget.onTap == null;
}

void main() {
  testWidgets('submit button is disabled when prompt is empty', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CreateScreen()));
    expect(_submitDisabled(tester), isTrue);
  });

  testWidgets('submit button is enabled when prompt has text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreateScreen(
          controller: StudioController(FakeStudioRepository()),
          activeConversationId: 'conversation-1',
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'paint a glass fox');
    await tester.pump();

    expect(_submitDisabled(tester), isFalse);
  });

  testWidgets('submit button stays disabled without an active session', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateScreen()));

    await tester.enterText(find.byType(TextField), 'paint a glass fox');
    await tester.pump();

    expect(_submitDisabled(tester), isTrue);
  });

  testWidgets('composer exposes a vision-to-prompt entry point', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreateScreen(
          controller: StudioController(FakeStudioRepository()),
          activeConversationId: 'conversation-1',
        ),
      ),
    );

    expect(find.text('识图'), findsOneWidget);
  });

  testWidgets('composer exposes a prompt optimizer entry point', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreateScreen(
          controller: StudioController(FakeStudioRepository()),
          activeConversationId: 'conversation-1',
        ),
      ),
    );

    expect(find.text('美化'), findsOneWidget);
  });

  testWidgets('composer exposes a style guide entry point and selects one', (
    tester,
  ) async {
    final repository = FakeStudioRepository();
    final controller = StudioController(repository);
    controller.replaceStyleGuides([
      StudioStyleGuide(
        id: 'style-1',
        name: 'Lia Noir',
        guide: 'Keep Lia with a black bob and red coat.',
        referenceImagePath: '2026/05/lia.png',
        createdAt: DateTime.utc(2026, 5, 20),
        updatedAt: DateTime.utc(2026, 5, 20),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: CreateScreen(
          controller: controller,
          activeConversationId: 'conversation-1',
        ),
      ),
    );

    expect(find.text('风格'), findsOneWidget);

    await tester.tap(find.text('风格'));
    await tester.pumpAndSettle();

    expect(find.text('风格 / 角色指南'), findsOneWidget);
    expect(find.text('Lia Noir'), findsOneWidget);

    await tester.tap(find.text('Lia Noir'));
    await tester.pumpAndSettle();

    expect(controller.state.activeStyleGuide?.id, 'style-1');
  });

  testWidgets('renders result image previews for successful turns', (
    tester,
  ) async {
    final controller = StudioController(FakeStudioRepository());
    controller.replaceTurns([
      StudioTurn(
        id: 'turn-success',
        conversationId: 'conversation-1',
        clientTaskId: 'task-success',
        taskId: 'task-success',
        mode: StudioTurnMode.generate,
        prompt: 'beautiful landscape',
        model: 'gpt-image-2',
        size: '1024x1024',
        resultImages: [
          StudioResultImage(
            url: Uri.parse('http://example.test/images/landscape.png'),
            path: '2026/05/landscape.png',
          ),
        ],
        status: StudioTurnStatus.success,
        error: '',
        updatedAt: DateTime.utc(2026, 5, 13),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: CreateScreen(controller: controller)),
    );

    expect(find.byType(Image), findsAtLeastNWidgets(1));
    expect(find.text('beautiful landscape'), findsOneWidget);
    expect(find.text('查看作品'), findsOneWidget);
  });

  testWidgets('tapping a result image opens the preview viewer', (
    tester,
  ) async {
    final controller = StudioController(FakeStudioRepository());
    controller.replaceTurns([
      StudioTurn(
        id: 'turn-success',
        conversationId: 'conversation-1',
        clientTaskId: 'task-success',
        taskId: 'task-success',
        mode: StudioTurnMode.generate,
        prompt: 'beautiful landscape',
        model: 'gpt-image-2',
        size: '1024x1024',
        resultImages: [
          StudioResultImage(
            url: Uri.parse('http://example.test/images/landscape.png'),
            path: '2026/05/landscape.png',
          ),
        ],
        status: StudioTurnStatus.success,
        error: '',
        updatedAt: DateTime.utc(2026, 5, 13),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: CreateScreen(controller: controller)),
    );

    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();

    // Viewer route is pushed — confirm we left the studio composer behind.
    expect(find.byKey(_submitKey), findsNothing);
  });

  testWidgets('success turns expose a detail entry point', (tester) async {
    final controller = StudioController(FakeStudioRepository());
    controller.replaceTurns([
      StudioTurn(
        id: 'turn-success',
        conversationId: 'conversation-1',
        clientTaskId: 'task-success',
        taskId: 'task-success',
        mode: StudioTurnMode.generate,
        prompt: 'beautiful landscape',
        model: 'gpt-image-2',
        size: '1024x1024',
        resultImages: [
          StudioResultImage(
            url: Uri.parse('http://example.test/images/landscape.png'),
            path: '2026/05/landscape.png',
          ),
        ],
        status: StudioTurnStatus.success,
        error: '',
        updatedAt: DateTime.utc(2026, 5, 13),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: CreateScreen(controller: controller)),
    );

    expect(find.text('详情'), findsOneWidget);
  });

  testWidgets(
    'prompt templates sheet shows reusable recipes and applies them',
    (tester) async {
      final controller = StudioController(FakeStudioRepository());
      controller.replaceRecipes([
        StudioRecipe(
          id: 'recipe-1',
          name: 'Orange recipe',
          prompt: 'orange product photo',
          model: 'gpt-image-2',
          size: '1024x1792',
          sourceImagePath: '2026/05/orange.png',
          sourceTurnId: 'turn-1',
          projectId: 'project-1',
          tags: const ['海报'],
          createdAt: DateTime.utc(2026, 5, 19),
          updatedAt: DateTime.utc(2026, 5, 19),
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: CreateScreen(
            controller: controller,
            activeConversationId: 'conversation-1',
          ),
        ),
      );

      await tester.tap(find.text('模板'));
      await tester.pumpAndSettle();

      expect(find.text('配方'), findsOneWidget);
      expect(find.text('Orange recipe'), findsOneWidget);

      await tester.tap(find.text('Orange recipe'));
      await tester.pumpAndSettle();

      expect(find.text('orange product photo'), findsOneWidget);
      expect(find.text('gpt-image-2'), findsOneWidget);
      expect(find.text('1024×1792'), findsOneWidget);
    },
  );

  testWidgets('recipe batch sheet submits one generation per input line', (
    tester,
  ) async {
    final repository = FakeStudioRepository();
    final controller = StudioController(repository);
    controller.replaceRecipes([
      StudioRecipe(
        id: 'recipe-1',
        name: 'Orange recipe',
        prompt: 'orange product photo for {item}',
        model: 'gpt-image-2',
        size: '1024x1792',
        sourceImagePath: '2026/05/orange.png',
        sourceTurnId: 'turn-1',
        projectId: 'project-1',
        tags: const ['海报'],
        createdAt: DateTime.utc(2026, 5, 19),
        updatedAt: DateTime.utc(2026, 5, 19),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: CreateScreen(
          controller: controller,
          activeConversationId: 'conversation-1',
        ),
      ),
    );

    await tester.tap(find.text('模板'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('批量生成 Orange recipe'));
    await tester.pumpAndSettle();

    expect(find.text('批量生成配方'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('recipe-batch-input')),
      'mug\nbottle',
    );
    await tester.tap(find.text('开始批量'));
    await tester.pumpAndSettle();

    expect(repository.createdPrompts, [
      'orange product photo for mug',
      'orange product photo for bottle',
    ]);
    expect(controller.state.turns.length, 2);
  });

  testWidgets('task center summarizes a batch run and retries failures', (
    tester,
  ) async {
    final repository = FakeStudioRepository();
    final controller = StudioController(repository);
    addTearDown(controller.dispose);
    await controller.submitRecipeBatch(
      conversationId: 'conversation-1',
      recipe: _recipe(),
      inputs: const ['mug', 'bottle', 'plate'],
    );
    controller.replaceTurns([
      _turn(id: 'turn-1', status: StudioTurnStatus.success),
      _turn(id: 'turn-2', status: StudioTurnStatus.error),
      _turn(id: 'turn-3', status: StudioTurnStatus.success),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: CreateScreen(
          controller: controller,
          activeConversationId: 'conversation-1',
        ),
      ),
    );

    expect(find.text('任务中心'), findsOneWidget);
    expect(find.text('Orange recipe'), findsOneWidget);
    expect(find.textContaining('1 失败'), findsOneWidget);

    await tester.tap(find.text('重试失败'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repository.retriedTurns, ['turn-2']);
  });

  testWidgets('renders shimmer placeholders for running turns', (tester) async {
    final controller = StudioController(FakeStudioRepository());
    controller.replaceTurns([
      StudioTurn(
        id: 'turn-running',
        conversationId: 'conversation-1',
        clientTaskId: 'task-running',
        taskId: 'task-running',
        mode: StudioTurnMode.generate,
        prompt: 'a running prompt',
        model: 'gpt-image-2',
        size: '1024x1024',
        resultImages: const [],
        status: StudioTurnStatus.running,
        error: '',
        updatedAt: DateTime.utc(2026, 5, 13),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: CreateScreen(controller: controller)),
    );

    expect(find.textContaining('正在'), findsOneWidget);
  });

  testWidgets('failed turns show the backend error and retry button', (
    tester,
  ) async {
    final controller = StudioController(FakeStudioRepository());
    controller.replaceTurns([
      StudioTurn(
        id: 'turn-error',
        conversationId: 'conversation-1',
        clientTaskId: 'task-error',
        taskId: 'task-error',
        mode: StudioTurnMode.generate,
        prompt: 'broken image',
        model: 'gpt-image-2',
        size: '1024x1024',
        resultImages: const [],
        status: StudioTurnStatus.error,
        error: 'upstream request failed',
        updatedAt: DateTime.utc(2026, 5, 13),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: CreateScreen(controller: controller)),
    );

    expect(find.text('upstream request failed'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('编辑 prompt'), findsOneWidget);
  });
}

StudioRecipe _recipe() {
  return StudioRecipe(
    id: 'recipe-1',
    name: 'Orange recipe',
    prompt: 'orange product photo for {item}',
    model: 'gpt-image-2',
    size: '1024x1792',
    sourceImagePath: '2026/05/orange.png',
    sourceTurnId: 'turn-1',
    projectId: 'project-1',
    tags: const ['海报'],
    createdAt: DateTime.utc(2026, 5, 19),
    updatedAt: DateTime.utc(2026, 5, 19),
  );
}

StudioTurn _turn({
  required String id,
  required StudioTurnStatus status,
  String prompt = 'orange product photo',
}) {
  return StudioTurn(
    id: id,
    conversationId: 'conversation-1',
    clientTaskId: 'task-$id',
    taskId: 'task-$id',
    mode: StudioTurnMode.generate,
    prompt: prompt,
    model: 'gpt-image-2',
    size: '1024x1792',
    resultImages: const [],
    status: status,
    error: status == StudioTurnStatus.error ? 'upstream failed' : '',
    updatedAt: DateTime.utc(2026, 5, 12),
  );
}

class FakeStudioRepository implements StudioRepositoryContract {
  final List<String> createdPrompts = [];
  final List<String> retriedTurns = [];
  int _generationCounter = 0;
  List<StudioStyleGuide> styleGuides = [];

  @override
  Future<List<StudioProject>> fetchProjects() async => [];

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
    return [];
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
  Future<List<StudioTurn>> fetchTurns(String conversationId) async => [];

  @override
  Future<StudioTurn> createGenerationTurn({
    required String conversationId,
    required String clientTaskId,
    required String prompt,
    required String model,
    String? size,
  }) async {
    createdPrompts.add(prompt);
    _generationCounter += 1;
    return StudioTurn(
      id: 'turn-$_generationCounter',
      conversationId: conversationId,
      clientTaskId: clientTaskId,
      taskId: clientTaskId,
      mode: StudioTurnMode.generate,
      prompt: prompt,
      model: model,
      size: size,
      resultImages: const [],
      status: StudioTurnStatus.success,
      error: '',
      updatedAt: DateTime.utc(2026, 5, 12),
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
  Future<String> draftPromptFromImage({
    required List<StudioEditImage> images,
  }) async {
    return 'cinematic product photo, warm rim light';
  }

  @override
  Future<String> optimizePrompt(String prompt) async {
    return 'A cinematic cyberpunk cat with neon rim light';
  }

  @override
  Future<StudioTurn> retryTurn({
    required String turnId,
    required String clientTaskId,
  }) async {
    retriedTurns.add(turnId);
    return _turn(id: turnId, status: StudioTurnStatus.success);
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
  Future<List<StudioRecipe>> fetchRecipes() async => const [];

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
  Future<void> deleteRecipe(String recipeId) async {}

  @override
  Future<List<StudioStyleGuide>> fetchStyleGuides() async => styleGuides;

  @override
  Future<StudioStyleGuide> createStyleGuide({
    required String name,
    required String guide,
    String referenceImagePath = '',
  }) async {
    final styleGuide = StudioStyleGuide(
      id: 'style-${styleGuides.length + 1}',
      name: name,
      guide: guide,
      referenceImagePath: referenceImagePath,
      createdAt: DateTime.utc(2026, 5, 20, 9, 30),
      updatedAt: DateTime.utc(2026, 5, 20, 9, 30),
    );
    styleGuides.add(styleGuide);
    return styleGuide;
  }

  @override
  Future<void> deleteStyleGuide(String styleGuideId) async {
    styleGuides.removeWhere((guide) => guide.id == styleGuideId);
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
