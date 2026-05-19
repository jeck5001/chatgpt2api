import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/app/accent.dart';
import 'package:image_studio_app/studio/projects_screen.dart';
import 'package:image_studio_app/studio/studio_models.dart';

void main() {
  testWidgets('renders projects and conversations', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectsScreen(
          projects: [
            StudioProject(
              id: 'project-1',
              name: 'Project One',
              ownerId: 'admin',
              archived: false,
              createdAt: DateTime.utc(2026, 5, 12),
              updatedAt: DateTime.utc(2026, 5, 12),
            ),
          ],
          conversations: [
            StudioConversation(
              id: 'conversation-1',
              projectId: 'project-1',
              title: 'Session One',
              mode: StudioTurnMode.generate,
              updatedAt: DateTime.utc(2026, 5, 12),
            ),
          ],
          activeProjectId: 'project-1',
          activeConversationId: 'conversation-1',
        ),
      ),
    );

    expect(find.text('Project One'), findsOneWidget);
    expect(find.text('Session One'), findsOneWidget);
  });

  testWidgets('tapping a conversation triggers selection callback', (
    tester,
  ) async {
    String? selectedConversationId;

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectsScreen(
          projects: [
            StudioProject(
              id: 'project-1',
              name: 'Project One',
              ownerId: 'admin',
              archived: false,
              createdAt: DateTime.utc(2026, 5, 12),
              updatedAt: DateTime.utc(2026, 5, 12),
            ),
          ],
          conversations: [
            StudioConversation(
              id: 'conversation-1',
              projectId: 'project-1',
              title: 'Session One',
              mode: StudioTurnMode.generate,
              updatedAt: DateTime.utc(2026, 5, 12),
            ),
          ],
          activeProjectId: 'project-1',
          activeConversationId: 'conversation-1',
          onConversationSelected: (conversationId) {
            selectedConversationId = conversationId;
          },
        ),
      ),
    );

    await tester.tap(find.text('Session One'));
    await tester.pump();

    expect(selectedConversationId, 'conversation-1');
  });

  testWidgets('tapping a project triggers selection callback', (tester) async {
    String? selectedProjectId;

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectsScreen(
          projects: [
            StudioProject(
              id: 'project-1',
              name: 'Project One',
              ownerId: 'admin',
              archived: false,
              createdAt: DateTime.utc(2026, 5, 12),
              updatedAt: DateTime.utc(2026, 5, 12),
            ),
          ],
          conversations: const [],
          activeProjectId: 'project-1',
          onProjectSelected: (projectId) {
            selectedProjectId = projectId;
          },
        ),
      ),
    );

    await tester.tap(find.text('Project One'));
    await tester.pump();

    expect(selectedProjectId, 'project-1');
  });

  testWidgets('active conversation chevron picks up the accent palette', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: KilnThemeScope(
          palette: KilnAccentPalette.sage,
          child: ProjectsScreen(
            projects: [
              StudioProject(
                id: 'project-1',
                name: 'Project One',
                ownerId: 'admin',
                archived: false,
                createdAt: DateTime.utc(2026, 5, 12),
                updatedAt: DateTime.utc(2026, 5, 12),
              ),
            ],
            conversations: [
              StudioConversation(
                id: 'conversation-1',
                projectId: 'project-1',
                title: 'Session One',
                mode: StudioTurnMode.generate,
                updatedAt: DateTime.utc(2026, 5, 12),
              ),
            ],
            activeProjectId: 'project-1',
            activeConversationId: 'conversation-1',
          ),
        ),
      ),
    );

    final chevron = tester.widget<Icon>(
      find.byIcon(Icons.chevron_right_rounded),
    );
    expect(chevron.color, KilnAccentPalette.sage.shade400);
  });
}
