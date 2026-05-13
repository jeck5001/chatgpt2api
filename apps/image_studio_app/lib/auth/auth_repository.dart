import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/storage/secure_token_store.dart';
import '../core/storage/server_profile_store.dart';
import 'auth_models.dart';

abstract interface class AuthRepositoryContract {
  Future<AuthSession> loginWithBearerKey({
    required Uri baseUrl,
    required String bearerKey,
  });

  Future<void> signOut();
}

class AuthRepository implements AuthRepositoryContract {
  AuthRepository({
    required SecureTokenStore tokenStore,
    required ServerProfileStore profileStore,
  }) : _tokenStore = tokenStore,
       _profileStore = profileStore;

  final SecureTokenStore _tokenStore;
  final ServerProfileStore _profileStore;

  @override
  Future<AuthSession> loginWithBearerKey({
    required Uri baseUrl,
    required String bearerKey,
  }) async {
    final dio = Dio(BaseOptions(baseUrl: baseUrl.toString()));
    final client = ApiClient(dio: dio, tokenProvider: () async => bearerKey);
    final payload = await client.getJson('/api/app/bootstrap');
    final identity = AuthIdentity.fromJson(
      payload['identity']! as Map<String, Object?>,
    );
    final session = AuthSession(
      baseUrl: baseUrl,
      token: bearerKey.trim(),
      identity: identity,
      version: payload['version'].toString(),
      capabilities: List<String>.from(payload['capabilities']! as List),
    );
    await _profileStore.writeActiveBaseUrl(baseUrl);
    await _tokenStore.writeToken(bearerKey);
    return session;
  }

  @override
  Future<void> signOut() async {
    await _tokenStore.clearToken();
  }
}
