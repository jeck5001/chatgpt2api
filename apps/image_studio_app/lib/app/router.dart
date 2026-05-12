import 'package:go_router/go_router.dart';

import '../auth/login_screen.dart';
import '../auth/onboarding_screen.dart';
import '../studio/create_screen.dart';

GoRouter buildRouter() {
  Uri? pendingBaseUrl;
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
          baseUrl: pendingBaseUrl ?? Uri.parse('http://localhost:8000'),
          onLogin: (_) async {
            context.go('/studio');
          },
        ),
      ),
      GoRoute(
        path: '/studio',
        builder: (context, state) => const CreateScreen(),
      ),
    ],
  );
}
