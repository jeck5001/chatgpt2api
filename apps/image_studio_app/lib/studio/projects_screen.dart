import 'package:flutter/material.dart';

import '../shared/empty_state.dart';
import 'studio_models.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({
    super.key,
    this.projects = const [],
    this.conversations = const [],
    this.activeProjectId,
    this.activeConversationId,
    this.onProjectSelected,
    this.onConversationSelected,
  });

  final List<StudioProject> projects;
  final List<StudioConversation> conversations;
  final String? activeProjectId;
  final String? activeConversationId;
  final ValueChanged<String>? onProjectSelected;
  final ValueChanged<String>? onConversationSelected;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return const EmptyState(
        title: 'Projects',
        message: 'Project and conversation switching will appear here.',
      );
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Projects', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          ...projects.map(
            (project) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(project.name),
              onTap: () => onProjectSelected?.call(project.id),
              leading: Icon(
                project.id == activeProjectId
                    ? Icons.folder
                    : Icons.folder_outlined,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Sessions', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          ...conversations.map(
            (conversation) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(conversation.title),
              onTap: () => onConversationSelected?.call(conversation.id),
              leading: Icon(
                conversation.id == activeConversationId
                    ? Icons.chat_bubble
                    : Icons.chat_bubble_outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
