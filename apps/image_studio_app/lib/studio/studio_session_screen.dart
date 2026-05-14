import 'package:flutter/material.dart';

import '../library/library_screen.dart';
import '../settings/settings_screen.dart';
import '../shared/adaptive_shell.dart';
import 'create_screen.dart';
import 'projects_screen.dart';
import 'studio_controller.dart';
import 'studio_models.dart';
import 'studio_result_viewer.dart';

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

  Future<String?> _promptForName({
    required String title,
    String hint = '',
    String confirmLabel = '创建',
  }) async {
    final field = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: field,
            autofocus: true,
            decoration: InputDecoration(hintText: hint),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(field.text.trim()),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    field.dispose();
    return result;
  }

  Future<void> _createProject() async {
    final name = await _promptForName(title: '新建项目', hint: '项目名称（可留空）');
    if (name == null) return;
    try {
      await widget.controller.createNewProject(name);
    } catch (error) {
      _toast('创建项目失败：$error');
    }
  }

  Future<void> _toggleFavorite(StudioFavorite favorite) async {
    try {
      await widget.controller.removeFavorite(favorite);
      _toast('已取消收藏');
    } catch (error) {
      _toast('操作失败：$error');
    }
  }

  void _openFavoriteInViewer(StudioFavorite favorite) {
    final uri = _resolveFavoriteUri(favorite);
    showStudioResultViewer(
      context,
      StudioResultImage(url: uri, path: favorite.imagePath),
    );
  }

  Uri _resolveFavoriteUri(StudioFavorite favorite) {
    final absolute = Uri.tryParse(favorite.imagePath);
    if (absolute != null && absolute.hasScheme) {
      return absolute;
    }
    final base =
        widget.controller.imageBaseUrl ?? Uri.parse('http://localhost:8000');
    return base.resolve(favorite.imagePath);
  }

  void _toast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
        final state = widget.controller.state;
        return AdaptiveShell(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          create: CreateScreen(controller: widget.controller),
          library: LibraryScreen(
            favorites: state.favorites,
            baseUrl: widget.controller.imageBaseUrl,
            onFavorite: _toggleFavorite,
            onContinueEdit: _openFavoriteInViewer,
          ),
          projects: ProjectsScreen(
            projects: state.projects,
            conversations: state.conversations,
            activeProjectId: state.activeProject?.id,
            activeConversationId: state.activeConversation?.id,
            onProjectSelected: (projectId) async {
              await widget.controller.selectProject(projectId);
            },
            onConversationSelected: (conversationId) async {
              await widget.controller.selectConversation(conversationId);
            },
            onCreateProject: _createProject,
          ),
          settings: SettingsScreen(
            preferences: state.preferences,
            onPreferencesChanged: widget.controller.updatePreferences,
          ),
        );
      },
    );
  }
}
