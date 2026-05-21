import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/auth/auth_repository.dart';
import 'package:image_studio_app/core/storage/secure_token_store.dart';
import 'package:image_studio_app/core/storage/server_profile_store.dart';

void main() {
  test(
    'restoreSavedSession rebuilds a session from saved credentials',
    () async {
      Uri? requestedBaseUrl;
      String? requestedBearerKey;

      final repository = AuthRepository(
        tokenStore: _MemoryTokenStore('  sk-saved  '),
        profileStore: _MemoryServerProfileStore(
          Uri.parse('https://api.example.test'),
        ),
        bootstrapLoader: ({required baseUrl, required bearerKey}) async {
          requestedBaseUrl = baseUrl;
          requestedBearerKey = bearerKey;
          return <String, Object?>{
            'identity': <String, Object?>{
              'id': 'admin',
              'name': '管理员',
              'role': 'admin',
            },
            'version': '1.2.3',
            'capabilities': <String>['studio', 'library'],
          };
        },
      );

      final session = await repository.restoreSavedSession();

      expect(requestedBaseUrl, Uri.parse('https://api.example.test'));
      expect(requestedBearerKey, 'sk-saved');
      expect(session, isNotNull);
      expect(session!.token, 'sk-saved');
      expect(session.baseUrl, Uri.parse('https://api.example.test'));
      expect(session.identity.name, '管理员');
      expect(session.capabilities, contains('library'));
    },
  );

  test('restoreSavedSession returns null without a saved token', () async {
    var bootstrapCalled = false;
    final repository = AuthRepository(
      tokenStore: _MemoryTokenStore(null),
      profileStore: _MemoryServerProfileStore(
        Uri.parse('https://api.example.test'),
      ),
      bootstrapLoader: ({required baseUrl, required bearerKey}) async {
        bootstrapCalled = true;
        return <String, Object?>{};
      },
    );

    final session = await repository.restoreSavedSession();

    expect(session, isNull);
    expect(bootstrapCalled, isFalse);
  });
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore(this.token);

  String? token;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String token) async {
    this.token = token.trim();
  }

  @override
  Future<void> clearToken() async {
    token = null;
  }
}

class _MemoryServerProfileStore implements ServerProfileStoreContract {
  _MemoryServerProfileStore(this.baseUrl);

  Uri? baseUrl;

  @override
  Uri? readActiveBaseUrl() => baseUrl;

  @override
  Future<void> writeActiveBaseUrl(Uri baseUrl) async {
    this.baseUrl = baseUrl;
  }

  @override
  Future<void> clearActiveBaseUrl() async {
    baseUrl = null;
  }
}
