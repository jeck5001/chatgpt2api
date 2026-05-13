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
    this.promptDraft = '',
    this.submitting = false,
    this.errorMessage,
  });

  final List<StudioProject> projects;
  final List<StudioConversation> conversations;
  final StudioProject? activeProject;
  final StudioConversation? activeConversation;
  final List<StudioTurn> turns;
  final String promptDraft;
  final bool submitting;
  final String? errorMessage;

  StudioState copyWith({
    List<StudioProject>? projects,
    List<StudioConversation>? conversations,
    StudioProject? activeProject,
    StudioConversation? activeConversation,
    List<StudioTurn>? turns,
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
      promptDraft: promptDraft ?? this.promptDraft,
      submitting: submitting ?? this.submitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class StudioController extends ChangeNotifier {
  StudioController(this._repository);

  final StudioRepositoryContract _repository;
  final Uuid _uuid = const Uuid();

  StudioState _state = const StudioState();
  StudioState get state => _state;

  bool get hasRunningTurns {
    return _state.turns.any((turn) => turn.isRunning);
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
    _state = _state.copyWith(
      projects: projects,
      conversations: conversations,
      activeProject: activeProject,
      activeConversation: activeConversation,
      turns: turns,
    );
    notifyListeners();
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
  }

  Future<void> selectProject(String projectId) async {
    final project = _state.projects.where((item) => item.id == projectId).firstOrNull;
    if (project == null) {
      return;
    }
    final conversations = await _repository.fetchConversations(project.id);
    final activeConversation = conversations.isNotEmpty ? conversations.first : null;
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
    final updated = <StudioTurn>[];
    for (final turn in _state.turns) {
      if (turn.isRunning) {
        updated.add(await _repository.syncTurn(turn.id));
      } else {
        updated.add(turn);
      }
    }
    _state = _state.copyWith(turns: updated);
    notifyListeners();
  }
}
