import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'defaults.dart';
import '../auth/auth_repository.dart';
import '../auth/login_screen.dart';
import '../auth/onboarding_screen.dart';
import '../core/api/api_client.dart';
import '../core/storage/secure_token_store.dart';
import '../core/storage/server_profile_store.dart';
import '../studio/studio_controller.dart';
import '../studio/studio_preferences.dart';
import '../studio/studio_repository.dart';
import '../studio/studio_session_screen.dart';

GoRouter buildRouter() {
  Uri? pendingBaseUrl;
  AuthRepository? activeAuthRepository;
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => OnboardingScreen(
          onContinue: (baseUrl) {
            pendingBaseUrl = baseUrl;
            context.go('/login');
          },
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          baseUrl: pendingBaseUrl ?? Uri.parse(defaultBackendUrl),
          onLogin: (bearerKey) async {
            final baseUrl = pendingBaseUrl ?? Uri.parse(defaultBackendUrl);
            final router = GoRouter.of(context);
            final sharedPrefs = await SharedPreferences.getInstance();
            final tokenStore = SecureTokenStore();
            final profileStore = ServerProfileStore(sharedPrefs);
            final authRepository = AuthRepository(
              tokenStore: tokenStore,
              profileStore: profileStore,
            );
            await authRepository.loginWithBearerKey(
              baseUrl: baseUrl,
              bearerKey: bearerKey,
            );
            activeAuthRepository = authRepository;
            final repository = StudioRepository(
              ApiClient(
                dio: Dio(BaseOptions(baseUrl: baseUrl.toString())),
                tokenProvider: () async => bearerKey,
              ),
            );
            final controller = StudioController(
              repository,
              imageBaseUrl: baseUrl,
              preferencesStore: SharedPreferencesStudioPreferencesStore(
                sharedPrefs,
              ),
            );
            router.go('/studio', extra: controller);
          },
        ),
      ),
      GoRoute(
        path: '/studio',
        builder: (context, state) {
          final controller = state.extra as StudioController?;
          if (controller == null) {
            return const Scaffold(
              body: Center(child: Text('Missing studio session')),
            );
          }
          return StudioSessionScreen(
            controller: controller,
            onSignOut: () async {
              final router = GoRouter.of(context);
              await activeAuthRepository?.signOut();
              activeAuthRepository = null;
              router.go('/');
            },
          );
        },
      ),
    ],
  );
}
