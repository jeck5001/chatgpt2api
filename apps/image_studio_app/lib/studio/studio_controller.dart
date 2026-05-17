import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'studio_models.dart';
import 'studio_preferences.dart';
import 'studio_repository.dart';

class StudioState {
  const StudioState({
    this.projects = const [],
    this.conversations = const [],
    this.activeProject,
    this.activeConversation,
    this.turns = const [],
    this.favorites = const [],
    this.templates = const [],
    this.preferences = const StudioPreferences(),
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
  final List<StudioPromptTemplate> templates;
  final StudioPreferences preferences;
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
    List<StudioPromptTemplate>? templates,
    StudioPreferences? preferences,
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
      templates: templates ?? this.templates,
      preferences: preferences ?? this.preferences,
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
    StudioPreferencesStore? preferencesStore,
  }) : _pollInterval = pollInterval ?? const Duration(seconds: 2),
       _preferencesStore = preferencesStore;

  final StudioRepositoryContract _repository;
  final Duration _pollInterval;
  final Uri? imageBaseUrl;
  final StudioPreferencesStore? _preferencesStore;
  final Uuid _uuid = const Uuid();

  StudioState _state = const StudioState();
  StudioState get state => _state;

  Timer? _pollTimer;
  bool _polling = false;

  Future<void> retryTurn(StudioTurn turn) async {
    if (turn.mode == StudioTurnMode.edit) {
      throw StateError('edit turns cannot be retried');
    }
    _state = _state.copyWith(clearError: true);
    try {
      final retried = await _repository.retryTurn(
        turnId: turn.id,
        clientTaskId: _uuid.v4(),
      );
      final replaced = _state.turns
          .map((t) => t.id == retried.id ? retried : t)
          .toList(growable: false);
      _state = _state.copyWith(turns: replaced);
      notifyListeners();
      _ensurePolling();
    } catch (error) {
      _state = _state.copyWith(errorMessage: error.toString());
      notifyListeners();
      rethrow;
    }
  }

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
    StudioPreferences? loadedPreferences;
    if (_preferencesStore != null) {
      try {
        loadedPreferences = await _preferencesStore.read();
      } catch (_) {
        loadedPreferences = null;
      }
    }
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
    List<StudioPromptTemplate> templates;
    try {
      templates = await _repository.fetchPromptTemplates();
    } catch (_) {
      templates = const [];
    }
    _state = _state.copyWith(
      projects: projects,
      conversations: conversations,
      activeProject: activeProject,
      activeConversation: activeConversation,
      turns: turns,
      favorites: favorites,
      templates: templates,
      preferences: loadedPreferences,
    );
    notifyListeners();
    _ensurePolling();
  }

  Future<void> updatePreferences(StudioPreferences preferences) async {
    _state = _state.copyWith(preferences: preferences);
    notifyListeners();
    final store = _preferencesStore;
    if (store == null) return;
    try {
      await store.write(preferences);
    } catch (_) {
      // Best-effort persistence; in-memory state is already updated.
    }
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

  Future<StudioProject> renameProject({
    required String projectId,
    required String name,
  }) async {
    final updated = await _repository.updateProject(
      projectId: projectId,
      name: name,
    );
    _replaceProject(updated);
    return updated;
  }

  Future<StudioProject> archiveProject({
    required String projectId,
    required bool archived,
  }) async {
    final updated = await _repository.updateProject(
      projectId: projectId,
      archived: archived,
    );
    _replaceProject(updated);
    return updated;
  }

  void _replaceProject(StudioProject updated) {
    final projects = _state.projects
        .map((p) => p.id == updated.id ? updated : p)
        .toList(growable: false);
    final activeProject = _state.activeProject?.id == updated.id
        ? updated
        : _state.activeProject;
    _state = _state.copyWith(projects: projects, activeProject: activeProject);
    notifyListeners();
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

  Future<void> deleteConversation(
    String conversationId, {
    bool purge = false,
  }) async {
    await _repository.deleteConversation(conversationId, purge: purge);
    final remaining = _state.conversations
        .where((c) => c.id != conversationId)
        .toList(growable: false);
    final wasActive = _state.activeConversation?.id == conversationId;
    if (!wasActive) {
      _state = _state.copyWith(conversations: remaining);
      notifyListeners();
      return;
    }
    final nextActive = remaining.isNotEmpty ? remaining.first : null;
    final nextTurns = nextActive == null
        ? const <StudioTurn>[]
        : await _repository.fetchTurns(nextActive.id);
    _state = StudioState(
      projects: _state.projects,
      conversations: remaining,
      activeProject: _state.activeProject,
      activeConversation: nextActive,
      turns: nextTurns,
      favorites: _state.favorites,
      templates: _state.templates,
      preferences: _state.preferences,
      promptDraft: _state.promptDraft,
      submitting: _state.submitting,
      errorMessage: _state.errorMessage,
    );
    notifyListeners();
    _ensurePolling();
  }

  Future<void> deleteTurn(String turnId, {bool purge = false}) async {
    await _repository.deleteTurn(turnId, purge: purge);
    _state = _state.copyWith(
      turns: _state.turns
          .where((turn) => turn.id != turnId)
          .toList(growable: false),
    );
    notifyListeners();
  }

  Future<StudioPromptTemplate> savePromptTemplate({
    required String name,
    required String content,
    String category = '',
  }) async {
    final created = await _repository.createPromptTemplate(
      name: name,
      category: category,
      content: content,
    );
    _state = _state.copyWith(
      templates: <StudioPromptTemplate>[..._state.templates, created],
    );
    notifyListeners();
    return created;
  }

  Future<void> deletePromptTemplate(String templateId) async {
    await _repository.deletePromptTemplate(templateId);
    _state = _state.copyWith(
      templates: _state.templates
          .where((t) => t.id != templateId)
          .toList(growable: false),
    );
    notifyListeners();
  }

  Future<void> submitGeneration({
    required String conversationId,
    required String prompt,
    String model = 'gpt-image-2',
    String? size = '1024x1024',
    int count = 1,
  }) async {
    final n = count < 1 ? 1 : count;
    _state = _state.copyWith(
      promptDraft: prompt,
      submitting: true,
      clearError: true,
    );
    notifyListeners();
    final created = <StudioTurn>[];
    try {
      for (var i = 0; i < n; i++) {
        final turn = await _repository.createGenerationTurn(
          conversationId: conversationId,
          clientTaskId: _uuid.v4(),
          prompt: prompt,
          model: model,
          size: size,
        );
        created.add(turn);
      }
      _state = _state.copyWith(
        turns: [...created.reversed, ..._state.turns],
        promptDraft: '',
        submitting: false,
      );
      notifyListeners();
      for (final turn in created) {
        if (turn.status == StudioTurnStatus.success) {
          await _maybeAutoFavorite(turn);
        }
      }
      _ensurePolling();
    } catch (error) {
      // Keep any partial successes so the user can see what landed.
      if (created.isNotEmpty) {
        _state = _state.copyWith(
          turns: [...created.reversed, ..._state.turns],
          submitting: false,
          errorMessage: error.toString(),
        );
      } else {
        _state = _state.copyWith(
          submitting: false,
          errorMessage: error.toString(),
        );
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> submitEdit({
    required String conversationId,
    required String prompt,
    required List<StudioEditImage> images,
    String model = 'gpt-image-2',
    String? size,
  }) async {
    if (images.isEmpty) {
      throw ArgumentError('submitEdit requires at least one reference image');
    }
    _state = _state.copyWith(
      promptDraft: prompt,
      submitting: true,
      clearError: true,
    );
    notifyListeners();
    try {
      final turn = await _repository.createEditTurn(
        conversationId: conversationId,
        clientTaskId: _uuid.v4(),
        prompt: prompt,
        model: model,
        size: size,
        images: images,
      );
      _state = _state.copyWith(
        turns: [turn, ..._state.turns],
        promptDraft: '',
        submitting: false,
      );
      notifyListeners();
      if (turn.status == StudioTurnStatus.success) {
        await _maybeAutoFavorite(turn);
      }
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
      final settled = <StudioTurn>[];
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
          if (turn.isRunning &&
              synced.status == StudioTurnStatus.success &&
              synced.resultImages.isNotEmpty) {
            settled.add(synced);
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
      for (final turn in settled) {
        await _maybeAutoFavorite(turn);
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _maybeAutoFavorite(StudioTurn turn) async {
    if (!_state.preferences.autoFavorite) return;
    for (final image in turn.resultImages) {
      if (image.path.isEmpty) continue;
      if (_state.favorites.any((fav) => fav.imagePath == image.path)) {
        continue;
      }
      try {
        final fav = await _repository.favoriteImage(
          imagePath: image.path,
          sourceTurnId: turn.id,
        );
        _state = _state.copyWith(
          favorites: <StudioFavorite>[..._state.favorites, fav],
        );
        notifyListeners();
      } catch (_) {
        // Best-effort — auto-favorite must never block other work.
      }
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
