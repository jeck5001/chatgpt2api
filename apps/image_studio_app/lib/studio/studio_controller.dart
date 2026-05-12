import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'studio_models.dart';
import 'studio_repository.dart';

class StudioState {
  const StudioState({
    this.turns = const [],
    this.promptDraft = '',
    this.submitting = false,
    this.errorMessage,
  });

  final List<StudioTurn> turns;
  final String promptDraft;
  final bool submitting;
  final String? errorMessage;

  StudioState copyWith({
    List<StudioTurn>? turns,
    String? promptDraft,
    bool? submitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StudioState(
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
