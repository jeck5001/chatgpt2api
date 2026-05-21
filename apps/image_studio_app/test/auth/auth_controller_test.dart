import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/auth/auth_controller.dart';
import 'package:image_studio_app/auth/auth_models.dart';
import 'package:image_studio_app/auth/auth_repository.dart';

void main() {
  test('login stores authenticated session', () async {
    final repository = FakeAuthRepository();
    final controller = AuthController(repository);

    await controller.loginWithBearerKey(
      baseUrl: Uri.parse('https://api.example.test'),
      bearerKey: 'sk-test',
    );

    expect(controller.state.session?.identity.name, '管理员');
    expect(repository.savedToken, 'sk-test');
  });

  test('sign out clears session and token', () async {
    final repository = FakeAuthRepository();
    final controller = AuthController(repository);
    await controller.loginWithBearerKey(
      baseUrl: Uri.parse('https://api.example.test'),
      bearerKey: 'sk-test',
    );

    await controller.signOut();

    expect(controller.state.session, isNull);
    expect(repository.savedToken, isNull);
  });
}

class FakeAuthRepository implements AuthRepositoryContract {
  String? savedToken;
  AuthSession? restoredSession;

  @override
  Future<AuthSession> loginWithBearerKey({
    required Uri baseUrl,
    required String bearerKey,
  }) async {
    savedToken = bearerKey;
    return AuthSession(
      baseUrl: baseUrl,
      token: bearerKey,
      identity: const AuthIdentity(
        id: 'admin',
        name: '管理员',
        role: AuthRole.admin,
      ),
      version: '0.1.0-test',
      capabilities: const ['studio'],
    );
  }

  @override
  Future<void> signOut() async {
    savedToken = null;
  }

  @override
  Future<AuthSession?> restoreSavedSession() async => restoredSession;
}
