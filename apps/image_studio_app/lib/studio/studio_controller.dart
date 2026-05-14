import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'studio_models.dart';
import 'studio_repository.dart';

class StudioState {
  const StudioState({
    this.projects = const [],
    this.conversations = const [],
    this.activeProject,
    this.activeConversation,
    this.turns = const [],
    this.favorites = const [],
    this.promptDraft = '',
    this.submitting = false,
    this.errorMessage,
  });

  final List<StudioProject> projects;
  final List<StudioConversation> conversations;
  final StudioProject? activeProject;
  final StudioConversation? activeConversation;
  final List<StudioTurn> turns;
  final List<StudioFavorite> favorites;
  final String promptDraft;
  final bool submitting;
  final String? errorMessage;

  StudioState copyWith({
    List<StudioProject>? projects,
    List<StudioConversation>? conversations,
    StudioProject? activeProject,
    StudioConversation? activeConversation,
    List<StudioTurn>? turns,
    List<StudioFavorite>? favorites,
    String? promptDraft,
    bool? submitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StudioState(
      projects: projects ?? this.projects,
      conversations: conversations ?? this.conversations,
      activeProject: activeProject ?? this.activeProject,
      activeConversation: activeConversation ?? this.activeConversation,
      turns: turns ?? this.turns,
      favorites: favorites ?? this.favorites,
      promptDraft: promptDraft ?? this.promptDraft,
      submitting: submitting ?? this.submitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class StudioController extends ChangeNotifier {
  StudioController(
    this._repository, {
    Duration? pollInterval,
    this.imageBaseUrl,
  }) : _pollInterval = pollInterval ?? const Duration(seconds: 2);

  final StudioRepositoryContract _repository;
  final Duration _pollInterval;
  final Uri? imageBaseUrl;
  final Uuid _uuid = const Uuid();

  StudioState _state = const StudioState();
  StudioState get state => _state;

  Timer? _pollTimer;
  bool _polling = false;

  bool get hasRunningTurns {
    return _state.turns.any((turn) => turn.isRunning);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    super.dispose();
  }

  void replaceTurns(List<StudioTurn> turns) {
    _state = _state.copyWith(turns: turns);
    notifyListeners();
  }

  Future<void> loadWorkspace() async {
    final projects = await _repository.fetchProjects();
    final activeProject = projects.isNotEmpty
        ? projects.first
        : await _repository.createProject('Untitled Project');
    final conversations = await _repository.fetchConversations(
      activeProject.id,
    );
    final activeConversation = conversations.isNotEmpty
        ? conversations.first
        : await _repository.createConversation(
            projectId: activeProject.id,
            title: 'New image session',
          );
    final turns = await _repository.fetchTurns(activeConversation.id);
    List<StudioFavorite> favorites;
    try {
      favorites = await _repository.fetchFavorites();
    } catch (_) {
      favorites = const [];
    }
    _state = _state.copyWith(
      projects: projects,
      conversations: conversations,
      activeProject: activeProject,
      activeConversation: activeConversation,
      turns: turns,
      favorites: favorites,
    );
    notifyListeners();
    _ensurePolling();
  }

  Future<void> selectConversation(String conversationId) async {
    final conversation = _state.conversations
        .where((item) => item.id == conversationId)
        .firstOrNull;
    if (conversation == null) {
      return;
    }
    final turns = await _repository.fetchTurns(conversation.id);
    _state = _state.copyWith(activeConversation: conversation, turns: turns);
    notifyListeners();
    _ensurePolling();
  }

  Future<void> selectProject(String projectId) async {
    final project = _state.projects
        .where((item) => item.id == projectId)
        .firstOrNull;
    if (project == null) {
      return;
    }
    final conversations = await _repository.fetchConversations(project.id);
    final activeConversation = conversations.isNotEmpty
        ? conversations.first
        : null;
    final turns = activeConversation == null
        ? const <StudioTurn>[]
        : await _repository.fetchTurns(activeConversation.id);
    _state = _state.copyWith(
      activeProject: project,
      conversations: conversations,
      activeConversation: activeConversation,
      turns: turns,
    );
    notifyListeners();
    _ensurePolling();
  }

  Future<StudioConversation> createNewConversation({
    required String title,
    StudioTurnMode mode = StudioTurnMode.generate,
  }) async {
    final project = _state.activeProject;
    if (project == null) {
      throw StateError('No active project to create a conversation under');
    }
    final conversation = await _repository.createConversation(
      projectId: project.id,
      title: title.isEmpty ? '新会话' : title,
      mode: mode == StudioTurnMode.edit ? 'edit' : 'generate',
    );
    _state = _state.copyWith(
      conversations: [conversation, ..._state.conversations],
      activeConversation: conversation,
      turns: const <StudioTurn>[],
    );
    notifyListeners();
    return conversation;
  }

  Future<StudioProject> createNewProject(String name) async {
    final project = await _repository.createProject(
      name.isEmpty ? '新项目' : name,
    );
    _state = _state.copyWith(
      projects: [project, ..._state.projects],
      activeProject: project,
      conversations: const <StudioConversation>[],
      activeConversation: null,
      turns: const <StudioTurn>[],
    );
    notifyListeners();
    return project;
  }

  Future<void> removeFavorite(StudioFavorite favorite) async {
    await _repository.deleteFavorite(favorite.id);
    _state = _state.copyWith(
      favorites: _state.favorites
          .where((fav) => fav.id != favorite.id)
          .toList(growable: false),
    );
    notifyListeners();
  }

  Future<void> submitGeneration({
    required String conversationId,
    required String prompt,
    String model = 'gpt-image-2',
    String? size = '1024x1024',
  }) async {
    _state = _state.copyWith(
      promptDraft: prompt,
      submitting: true,
      clearError: true,
    );
    notifyListeners();
    try {
      final turn = await _repository.createGenerationTurn(
        conversationId: conversationId,
        clientTaskId: _uuid.v4(),
        prompt: prompt,
        model: model,
        size: size,
      );
      _state = _state.copyWith(
        turns: [turn, ..._state.turns],
        promptDraft: '',
        submitting: false,
      );
      notifyListeners();
      _ensurePolling();
    } catch (error) {
      _state = _state.copyWith(
        submitting: false,
        errorMessage: error.toString(),
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> pollRunningTurnsOnce() async {
    if (_polling) return;
    _polling = true;
    try {
      final source = _state.turns;
      final updated = <StudioTurn>[];
      var changed = false;
      for (final turn in source) {
        if (!turn.isRunning) {
          updated.add(turn);
          continue;
        }
        try {
          final synced = await _repository.syncTurn(turn.id);
          updated.add(synced);
          if (synced.status != turn.status ||
              synced.resultImages.length != turn.resultImages.length ||
              synced.error != turn.error) {
            changed = true;
          }
        } catch (_) {
          // Per-turn error: keep the previous snapshot so the rest of
          // the list still gets polled. The next tick will retry.
          updated.add(turn);
        }
      }
      if (changed || updated.length != source.length) {
        _state = _state.copyWith(turns: updated);
        notifyListeners();
      }
    } finally {
      _polling = false;
    }
  }

  bool isFavoriteImage(StudioResultImage image) {
    if (image.path.isEmpty) return false;
    return _state.favorites.any((fav) => fav.imagePath == image.path);
  }

  Future<void> toggleFavoriteImage({
    required StudioResultImage image,
    String sourceTurnId = '',
  }) async {
    if (image.path.isEmpty) return;
    final existing = _state.favorites
        .where((fav) => fav.imagePath == image.path)
        .firstOrNull;
    if (existing != null) {
      await _repository.deleteFavorite(existing.id);
      _state = _state.copyWith(
        favorites: _state.favorites
            .where((fav) => fav.id != existing.id)
            .toList(growable: false),
      );
    } else {
      final fav = await _repository.favoriteImage(
        imagePath: image.path,
        sourceTurnId: sourceTurnId,
      );
      _state = _state.copyWith(
        favorites: <StudioFavorite>[..._state.favorites, fav],
      );
    }
    notifyListeners();
  }

  void _ensurePolling() {
    if (_pollTimer != null) return;
    if (!hasRunningTurns) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      try {
        await pollRunningTurnsOnce();
      } catch (_) {
        // Swallow transient poll errors — next tick will retry.
      }
      if (!hasRunningTurns) {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
    });
  }
}
