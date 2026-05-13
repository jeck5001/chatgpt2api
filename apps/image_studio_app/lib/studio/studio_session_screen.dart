import 'package:flutter/material.dart';

import '../library/library_screen.dart';
import '../settings/settings_screen.dart';
import '../shared/adaptive_shell.dart';
import 'create_screen.dart';
import 'studio_controller.dart';
import 'projects_screen.dart';

class StudioSessionScreen extends StatefulWidget {
  const StudioSessionScreen({super.key, required this.controller});

  final StudioController controller;

  @override
  State<StudioSessionScreen> createState() => _StudioSessionScreenState();
}

class _StudioSessionScreenState extends State<StudioSessionScreen> {
  late final Future<void> _loadFuture;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _loadFuture = widget.controller.loadWorkspace();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load studio workspace: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return AdaptiveShell(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          create: CreateScreen(controller: widget.controller),
          library: const LibraryScreen(),
          projects: ProjectsScreen(
            projects: widget.controller.state.projects,
            conversations: widget.controller.state.conversations,
            activeProjectId: widget.controller.state.activeProject?.id,
            activeConversationId:
                widget.controller.state.activeConversation?.id,
            onProjectSelected: (projectId) async {
              await widget.controller.selectProject(projectId);
            },
            onConversationSelected: (conversationId) async {
              await widget.controller.selectConversation(conversationId);
            },
          ),
          settings: const SettingsScreen(),
        );
      },
    );
  }
}
