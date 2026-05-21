import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/storage/secure_token_store.dart';
import '../core/storage/server_profile_store.dart';
import 'auth_models.dart';

typedef AuthBootstrapLoader =
    Future<Map<String, Object?>> Function({
      required Uri baseUrl,
      required String bearerKey,
    });

abstract interface class AuthRepositoryContract {
  Future<AuthSession> loginWithBearerKey({
    required Uri baseUrl,
    required String bearerKey,
  });

  Future<AuthSession?> restoreSavedSession();

  Future<void> signOut();
}

class AuthRepository implements AuthRepositoryContract {
  AuthRepository({
    required TokenStore tokenStore,
    required ServerProfileStoreContract profileStore,
    AuthBootstrapLoader? bootstrapLoader,
  }) : _tokenStore = tokenStore,
       _profileStore = profileStore,
       _bootstrapLoader = bootstrapLoader ?? _loadBootstrap;

  final TokenStore _tokenStore;
  final ServerProfileStoreContract _profileStore;
  final AuthBootstrapLoader _bootstrapLoader;

  @override
  Future<AuthSession> loginWithBearerKey({
    required Uri baseUrl,
    required String bearerKey,
  }) async {
    final session = await _createSession(
      baseUrl: baseUrl,
      bearerKey: bearerKey,
    );
    await _profileStore.writeActiveBaseUrl(baseUrl);
    await _tokenStore.writeToken(session.token);
    return session;
  }

  @override
  Future<AuthSession?> restoreSavedSession() async {
    final baseUrl = _profileStore.readActiveBaseUrl();
    if (baseUrl == null) {
      return null;
    }
    final bearerKey = (await _tokenStore.readToken())?.trim();
    if (bearerKey == null || bearerKey.isEmpty) {
      return null;
    }
    return _createSession(baseUrl: baseUrl, bearerKey: bearerKey);
  }

  Future<AuthSession> _createSession({
    required Uri baseUrl,
    required String bearerKey,
  }) async {
    final normalizedToken = bearerKey.trim();
    final payload = await _bootstrapLoader(
      baseUrl: baseUrl,
      bearerKey: normalizedToken,
    );
    final identity = AuthIdentity.fromJson(
      payload['identity']! as Map<String, Object?>,
    );
    return AuthSession(
      baseUrl: baseUrl,
      token: normalizedToken,
      identity: identity,
      version: payload['version'].toString(),
      capabilities: List<String>.from(payload['capabilities']! as List),
    );
  }

  @override
  Future<void> signOut() async {
    await _tokenStore.clearToken();
  }

  static Future<Map<String, Object?>> _loadBootstrap({
    required Uri baseUrl,
    required String bearerKey,
  }) async {
    final dio = Dio(BaseOptions(baseUrl: baseUrl.toString()));
    final client = ApiClient(dio: dio, tokenProvider: () async => bearerKey);
    return client.getJson('/api/app/bootstrap');
  }
}
