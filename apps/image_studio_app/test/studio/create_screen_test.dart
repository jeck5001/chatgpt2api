import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/studio/create_screen.dart';
import 'package:image_studio_app/studio/studio_controller.dart';
import 'package:image_studio_app/studio/studio_models.dart';
import 'package:image_studio_app/studio/studio_repository.dart';

void main() {
  testWidgets('generate button is disabled when prompt is empty', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateScreen()));

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Generate'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('generate button is enabled when prompt has text', (
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

    await tester.enterText(find.byType(TextField), 'paint a glass fox');
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Generate'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('generate button stays disabled without an active session', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateScreen()));

    await tester.enterText(find.byType(TextField), 'paint a glass fox');
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Generate'),
    );
    expect(button.onPressed, isNull);
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

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('beautiful landscape'), findsOneWidget);
  });
}

class FakeStudioRepository implements StudioRepositoryContract {
  @override
  Future<List<StudioProject>> fetchProjects() async => [];

  @override
  Future<StudioProject> createProject(String name) async {
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
    return StudioTurn(
      id: 'turn-1',
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
  Future<List<StudioFavorite>> fetchFavorites() async => [];

  @override
  Future<StudioFavorite> favoriteImage({
    required String imagePath,
    String sourceTurnId = '',
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteFavorite(String favoriteId) async {}
}
