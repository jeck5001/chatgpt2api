import 'package:flutter/foundation.dart';

import 'auth_models.dart';
import 'auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepositoryContract _repository;

  AuthState _state = const AuthState();
  AuthState get state => _state;

  Future<void> loginWithBearerKey({
    required Uri baseUrl,
    required String bearerKey,
  }) async {
    _state = _state.copyWith(loading: true, clearError: true);
    notifyListeners();
    try {
      final session = await _repository.loginWithBearerKey(
        baseUrl: baseUrl,
        bearerKey: bearerKey,
      );
      _state = AuthState(session: session);
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(
        loading: false,
        errorMessage: error.toString(),
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _state = _state.copyWith(clearSession: true, clearError: true);
    notifyListeners();
  }
}
