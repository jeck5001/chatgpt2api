import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'defaults.dart';
import '../auth/auth_models.dart';
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

typedef StudioRouteArgs = ({StudioController controller, AuthSession session});

GoRouter buildRouter() {
  Uri? pendingBaseUrl;
  AuthRepository? activeAuthRepository;
  Future<StudioRouteArgs?>? restoreFuture;

  StudioRouteArgs createStudioRouteArgs({
    required SharedPreferences sharedPrefs,
    required AuthSession session,
  }) {
    final baseUrl = session.baseUrl;
    final token = session.token;
    final repository = StudioRepository(
      ApiClient(
        dio: Dio(BaseOptions(baseUrl: baseUrl.toString())),
        tokenProvider: () async => token,
      ),
    );
    final controller = StudioController(
      repository,
      imageBaseUrl: baseUrl,
      preferencesStore: SharedPreferencesStudioPreferencesStore(sharedPrefs),
    );
    return (controller: controller, session: session);
  }

  Future<StudioRouteArgs?> restoreSavedRouteArgs() async {
    try {
      final sharedPrefs = await SharedPreferences.getInstance();
      final tokenStore = SecureTokenStore();
      final profileStore = ServerProfileStore(sharedPrefs);
      final authRepository = AuthRepository(
        tokenStore: tokenStore,
        profileStore: profileStore,
      );
      final session = await authRepository.restoreSavedSession();
      if (session == null) {
        return null;
      }
      activeAuthRepository = authRepository;
      return createStudioRouteArgs(sharedPrefs: sharedPrefs, session: session);
    } catch (_) {
      return null;
    }
  }

  Future<void> signOutAndReturnHome(BuildContext context) async {
    final router = GoRouter.of(context);
    await activeAuthRepository?.signOut();
    activeAuthRepository = null;
    pendingBaseUrl = null;
    restoreFuture = Future<StudioRouteArgs?>.value(null);
    router.go('/');
  }

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          restoreFuture ??= restoreSavedRouteArgs();
          return FutureBuilder<StudioRouteArgs?>(
            future: restoreFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _StartupScreen();
              }
              final restoredArgs = snapshot.data;
              if (restoredArgs != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    context.go('/studio', extra: restoredArgs);
                  }
                });
                return const _StartupScreen();
              }
              return OnboardingScreen(
                onContinue: (baseUrl) {
                  pendingBaseUrl = baseUrl;
                  context.go('/login');
                },
              );
            },
          );
        },
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
            final session = await authRepository.loginWithBearerKey(
              baseUrl: baseUrl,
              bearerKey: bearerKey,
            );
            activeAuthRepository = authRepository;
            router.go(
              '/studio',
              extra: createStudioRouteArgs(
                sharedPrefs: sharedPrefs,
                session: session,
              ),
            );
          },
        ),
      ),
      GoRoute(
        path: '/studio',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is StudioRouteArgs) {
            return StudioSessionScreen(
              controller: extra.controller,
              session: extra.session,
              onSignOut: () => signOutAndReturnHome(context),
            );
          }
          if (extra is StudioController) {
            return StudioSessionScreen(
              controller: extra,
              onSignOut: () => signOutAndReturnHome(context),
            );
          }
          return const Scaffold(
            body: Center(child: Text('Missing studio session')),
          );
        },
      ),
    ],
  );
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
