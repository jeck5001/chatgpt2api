# Cross-Platform Image Studio App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter-based native-feeling image studio app for iOS, Android, macOS, Windows, and Linux that connects to the existing chatgpt2api FastAPI backend.

**Architecture:** Keep FastAPI as the source of truth and use the server-backed studio project/conversation/turn/favorite APIs already implemented on `codex/internal-image-studio`. Add one focused Flutter app under `apps/image_studio_app`, with Riverpod-owned state, Dio-based HTTP, secure credential storage, adaptive navigation, and CI build workflows.

**Tech Stack:** Python 3.13, FastAPI, unittest/TestClient, Flutter stable, Dart 3, Riverpod, go_router, Dio, flutter_secure_storage, shared_preferences, freezed/json_serializable, GitHub Actions.

---

## Scope Boundary

This plan builds the first app version as an online AI image studio. It does not build a full admin console, payment flow, public sharing system, or offline generation queue.

Authentication in the current backend is bearer-key based through `POST /auth/login`. The app must support API key / bearer key mode in v1. Username/password login needs a new backend credential exchange endpoint and should be implemented only after the backend contract is explicitly added.

## File Structure

Backend integration files:

- Modify `api/app.py`: include `api.studio.create_router()` after integrating `codex/internal-image-studio`.
- Modify `api/system.py`: add a lightweight authenticated app bootstrap endpoint if not already present.
- Create `test/test_app_bootstrap_api.py`: validate bootstrap response for Flutter onboarding.

Flutter app files:

- Create `apps/image_studio_app/pubspec.yaml`: Flutter dependencies, assets, package metadata.
- Create `apps/image_studio_app/analysis_options.yaml`: strict Dart analysis configuration.
- Create `apps/image_studio_app/lib/main.dart`: app entrypoint.
- Create `apps/image_studio_app/lib/app/image_studio_app.dart`: root `MaterialApp.router`.
- Create `apps/image_studio_app/lib/app/router.dart`: go_router route graph and auth redirects.
- Create `apps/image_studio_app/lib/app/theme.dart`: dark creative workspace theme and adaptive density.
- Create `apps/image_studio_app/lib/app/responsive.dart`: compact, medium, expanded breakpoint helpers.
- Create `apps/image_studio_app/lib/core/api/api_client.dart`: Dio setup, base URL, bearer header, JSON/form helpers.
- Create `apps/image_studio_app/lib/core/api/api_error.dart`: normalized API/network error model.
- Create `apps/image_studio_app/lib/core/storage/secure_token_store.dart`: secure token persistence.
- Create `apps/image_studio_app/lib/core/storage/server_profile_store.dart`: local server profile and app preference persistence.
- Create `apps/image_studio_app/lib/auth/auth_models.dart`: server profile, auth mode, session models.
- Create `apps/image_studio_app/lib/auth/auth_repository.dart`: server validation, bearer-key login, sign-out.
- Create `apps/image_studio_app/lib/auth/auth_controller.dart`: Riverpod session controller.
- Create `apps/image_studio_app/lib/auth/onboarding_screen.dart`: server URL and auth mode setup.
- Create `apps/image_studio_app/lib/auth/login_screen.dart`: bearer key login UI.
- Create `apps/image_studio_app/lib/studio/studio_models.dart`: project, conversation, turn, template, favorite models.
- Create `apps/image_studio_app/lib/studio/studio_repository.dart`: studio API methods.
- Create `apps/image_studio_app/lib/studio/studio_controller.dart`: selected project/conversation, active turns, drafts, polling.
- Create `apps/image_studio_app/lib/studio/create_screen.dart`: prompt composer and latest results.
- Create `apps/image_studio_app/lib/studio/projects_screen.dart`: project and conversation browser.
- Create `apps/image_studio_app/lib/studio/turn_detail_screen.dart`: prompt/result/error/retry detail.
- Create `apps/image_studio_app/lib/library/library_screen.dart`: recent and favorite images.
- Create `apps/image_studio_app/lib/settings/settings_screen.dart`: server, session, cache, sign-out.
- Create `apps/image_studio_app/lib/shared/adaptive_shell.dart`: mobile tabs, tablet two-pane, desktop three-pane shell.
- Create `apps/image_studio_app/lib/shared/image_result_card.dart`: reusable image card actions.
- Create `apps/image_studio_app/lib/shared/empty_state.dart`: consistent empty and error states.

Flutter test files:

- Create `apps/image_studio_app/test/core/api_client_test.dart`: API header and error normalization tests.
- Create `apps/image_studio_app/test/auth/auth_controller_test.dart`: session persistence and sign-out tests.
- Create `apps/image_studio_app/test/studio/studio_models_test.dart`: JSON parsing tests.
- Create `apps/image_studio_app/test/studio/studio_controller_test.dart`: polling and draft behavior tests.
- Create `apps/image_studio_app/test/shared/adaptive_shell_test.dart`: compact, medium, expanded layout tests.
- Create `apps/image_studio_app/test/studio/create_screen_test.dart`: composer validation and submit behavior tests.

CI files:

- Create `.github/workflows/flutter-app.yml`: analyze, test, Android build, Linux build, Windows build, macOS build, iOS no-codesign build.

---

## Task 1: Integrate Server-Backed Studio APIs

**Files:**
- Modify: `api/app.py`
- Modify: `services/storage/base.py`
- Modify: `services/storage/json_storage.py`
- Modify: `services/storage/database_storage.py`
- Modify: `services/storage/git_storage.py`
- Modify: `services/storage/factory.py`
- Modify: `services/image_task_service.py`
- Create: `services/studio_service.py`
- Create: `api/studio.py`
- Create: `test/test_studio_service.py`
- Create: `test/test_studio_api.py`

- [ ] **Step 1: Cherry-pick the existing studio backend commits**

Run:

```bash
git cherry-pick 6ea5ef8 5df320e b816dc5 9e69e59 89f4fd4 dd5f2c8 443688a 0f68446 b4cb306 0a8d2f0 5849001 421e687 98e23ce a7bd5d3
```

Expected: commits apply cleanly or stop with conflicts only in files listed in this task.

- [ ] **Step 2: Verify the studio router is mounted**

Confirm `api/app.py` contains:

```python
from api import accounts, ai, image_tasks, register, studio, system
```

Confirm `create_app()` includes:

```python
    app.include_router(studio.create_router())
```

The studio router must be included before `system.create_router(app_version)` so `/api/...` routes win over the static web fallback.

- [ ] **Step 3: Run backend studio tests**

Run:

```bash
uv run python -m unittest test.test_studio_service test.test_studio_api -v
```

Expected: PASS.

- [ ] **Step 4: Run image task regression tests**

Run:

```bash
uv run python -m unittest test.test_image_tasks_api test.test_image_task_service -v
```

Expected: PASS.

- [ ] **Step 5: Commit backend API integration**

Run:

```bash
git add api/app.py api/studio.py services/studio_service.py services/storage/base.py services/storage/json_storage.py services/storage/database_storage.py services/storage/git_storage.py services/storage/factory.py services/image_task_service.py test/test_studio_service.py test/test_studio_api.py test/test_image_tasks_api.py
git commit -m "feat: integrate server-backed image studio api"
```

## Task 2: Add App Bootstrap Endpoint

**Files:**
- Modify: `api/system.py`
- Create: `test/test_app_bootstrap_api.py`

- [ ] **Step 1: Write the failing bootstrap API test**

Create `test/test_app_bootstrap_api.py`:

```python
from __future__ import annotations

import unittest

from fastapi import FastAPI
from fastapi.testclient import TestClient

from api import system as system_module


AUTH_HEADERS = {"Authorization": "Bearer chatgpt2api"}


class AppBootstrapApiTests(unittest.TestCase):
    def setUp(self):
        app = FastAPI()
        app.include_router(system_module.create_router("0.1.0-test"))
        self.client = TestClient(app)

    def test_bootstrap_returns_identity_and_capabilities(self):
        response = self.client.get("/api/app/bootstrap", headers=AUTH_HEADERS)

        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()
        self.assertEqual(payload["version"], "0.1.0-test")
        self.assertEqual(payload["identity"]["role"], "admin")
        self.assertIn("studio", payload["capabilities"])
        self.assertIn("image_generation", payload["capabilities"])

    def test_bootstrap_rejects_missing_auth(self):
        response = self.client.get("/api/app/bootstrap")

        self.assertEqual(response.status_code, 401)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the failing bootstrap test**

Run:

```bash
uv run python -m unittest test.test_app_bootstrap_api -v
```

Expected: FAIL with `404 Not Found` for `/api/app/bootstrap`.

- [ ] **Step 3: Implement the endpoint**

In `api/system.py`, add this route inside `create_router(app_version)` after `/auth/login`:

```python
    @router.get("/api/app/bootstrap")
    async def get_app_bootstrap(authorization: str | None = Header(default=None)):
        identity = require_identity(authorization)
        return {
            "version": app_version,
            "identity": {
                "id": identity.get("id"),
                "name": identity.get("name"),
                "role": identity.get("role"),
            },
            "capabilities": [
                "studio",
                "image_generation",
                "image_edit",
                "prompt_templates",
                "favorites",
            ],
            "auth_modes": ["bearer_key"],
        }
```

- [ ] **Step 4: Run the bootstrap test**

Run:

```bash
uv run python -m unittest test.test_app_bootstrap_api -v
```

Expected: PASS.

- [ ] **Step 5: Commit bootstrap endpoint**

Run:

```bash
git add api/system.py test/test_app_bootstrap_api.py
git commit -m "feat: add app bootstrap endpoint"
```

## Task 3: Scaffold Flutter App

**Files:**
- Create: `apps/image_studio_app/**`
- Modify: `.gitignore`

- [ ] **Step 1: Verify Flutter is available**

Run:

```bash
flutter --version
```

Expected: Flutter stable is installed. If it is missing locally, install Flutter before local development; GitHub Actions will install it in CI.

- [ ] **Step 2: Create the app scaffold**

Run:

```bash
mkdir -p apps
flutter create apps/image_studio_app --org com.jeck5001 --project-name image_studio_app --platforms ios,android,macos,windows,linux
```

Expected: Flutter creates `apps/image_studio_app/pubspec.yaml`, platform folders, `lib/main.dart`, and `test/widget_test.dart`.

- [ ] **Step 3: Add dependencies**

In `apps/image_studio_app/pubspec.yaml`, ensure the dependency sections include:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  dio: ^5.9.0
  flutter_riverpod: ^3.0.3
  flutter_secure_storage: ^10.0.0-beta.4
  go_router: ^17.0.0
  json_annotation: ^4.9.0
  shared_preferences: ^2.5.3
  uuid: ^4.5.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.10.2
  flutter_lints: ^6.0.0
  freezed: ^3.2.3
  freezed_annotation: ^3.1.0
  json_serializable: ^6.11.1
  mocktail: ^1.0.4
```

- [ ] **Step 4: Tighten analysis**

Create `apps/image_studio_app/analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    always_declare_return_types: true
    avoid_dynamic_calls: true
    prefer_final_locals: true
    require_trailing_commas: true
    sort_child_properties_last: true
    unawaited_futures: true
```

- [ ] **Step 5: Ignore Flutter generated local files**

Add these lines to `.gitignore`:

```gitignore
# Flutter local build artifacts
apps/image_studio_app/.dart_tool/
apps/image_studio_app/.flutter-plugins
apps/image_studio_app/.flutter-plugins-dependencies
apps/image_studio_app/build/
```

- [ ] **Step 6: Install Flutter packages**

Run:

```bash
cd apps/image_studio_app && flutter pub get
```

Expected: PASS and `apps/image_studio_app/pubspec.lock` is created.

- [ ] **Step 7: Run initial Flutter tests**

Run:

```bash
cd apps/image_studio_app && flutter test
```

Expected: PASS with the default widget test or updated smoke test.

- [ ] **Step 8: Commit scaffold**

Run:

```bash
git add .gitignore apps/image_studio_app
git commit -m "feat: scaffold flutter image studio app"
```

## Task 4: Build Core API and Storage Layer

**Files:**
- Create: `apps/image_studio_app/lib/core/api/api_error.dart`
- Create: `apps/image_studio_app/lib/core/api/api_client.dart`
- Create: `apps/image_studio_app/lib/core/storage/secure_token_store.dart`
- Create: `apps/image_studio_app/lib/core/storage/server_profile_store.dart`
- Create: `apps/image_studio_app/test/core/api_client_test.dart`

- [ ] **Step 1: Write API client tests**

Create `apps/image_studio_app/test/core/api_client_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/core/api/api_client.dart';
import 'package:image_studio_app/core/api/api_error.dart';

void main() {
  test('adds bearer token to requests', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    final client = ApiClient(
      dio: dio,
      tokenProvider: () async => 'sk-test',
    );

    final options = RequestOptions(path: '/api/projects');
    final handler = _RequestHandler();
    await client.authInterceptor.onRequest(options, handler);

    expect(handler.options.headers['Authorization'], 'Bearer sk-test');
  });

  test('normalizes structured backend errors', () {
    final error = ApiError.fromDioException(
      DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 401,
          data: <String, Object?>{
            'detail': <String, Object?>{'error': '密钥无效或已失效，请重新登录'},
          },
        ),
      ),
    );

    expect(error.message, '密钥无效或已失效，请重新登录');
    expect(error.statusCode, 401);
  });
}

class _RequestHandler extends RequestInterceptorHandler {
  late RequestOptions options;

  @override
  void next(RequestOptions requestOptions) {
    options = requestOptions;
  }
}
```

- [ ] **Step 2: Run the failing tests**

Run:

```bash
cd apps/image_studio_app && flutter test test/core/api_client_test.dart
```

Expected: FAIL because `ApiClient` and `ApiError` do not exist.

- [ ] **Step 3: Implement `ApiError`**

Create `apps/image_studio_app/lib/core/api/api_error.dart`:

```dart
import 'package:dio/dio.dart';

class ApiError implements Exception {
  const ApiError({
    required this.message,
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  factory ApiError.fromDioException(DioException exception) {
    final response = exception.response;
    final data = response?.data;
    final message = _extractMessage(data) ?? exception.message ?? 'Network request failed';
    return ApiError(message: message, statusCode: response?.statusCode);
  }

  static String? _extractMessage(Object? data) {
    if (data case {'detail': {'error': final Object error}}) {
      return error.toString();
    }
    if (data case {'error': final Object error}) {
      return error.toString();
    }
    if (data case {'detail': final Object detail}) {
      return detail.toString();
    }
    return null;
  }

  @override
  String toString() => message;
}
```

- [ ] **Step 4: Implement `ApiClient`**

Create `apps/image_studio_app/lib/core/api/api_client.dart`:

```dart
import 'package:dio/dio.dart';

typedef TokenProvider = Future<String?> Function();

class ApiClient {
  ApiClient({
    required Dio dio,
    required TokenProvider tokenProvider,
  })  : _dio = dio,
        _tokenProvider = tokenProvider {
    _dio.interceptors.add(authInterceptor);
  }

  final Dio _dio;
  final TokenProvider _tokenProvider;

  late final InterceptorsWrapper authInterceptor = InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await _tokenProvider();
      if (token != null && token.trim().isNotEmpty) {
        options.headers['Authorization'] = 'Bearer ${token.trim()}';
      }
      handler.next(options);
    },
  );

  Future<Map<String, Object?>> getJson(String path, {Map<String, Object?>? query}) async {
    final response = await _dio.get<Map<String, Object?>>(path, queryParameters: query);
    return response.data ?? <String, Object?>{};
  }

  Future<Map<String, Object?>> postJson(String path, {Object? body}) async {
    final response = await _dio.post<Map<String, Object?>>(path, data: body ?? <String, Object?>{});
    return response.data ?? <String, Object?>{};
  }

  Future<Map<String, Object?>> patchJson(String path, {Object? body}) async {
    final response = await _dio.patch<Map<String, Object?>>(path, data: body ?? <String, Object?>{});
    return response.data ?? <String, Object?>{};
  }

  Future<Map<String, Object?>> deleteJson(String path) async {
    final response = await _dio.delete<Map<String, Object?>>(path);
    return response.data ?? <String, Object?>{};
  }
}
```

- [ ] **Step 5: Implement secure token store**

Create `apps/image_studio_app/lib/core/storage/secure_token_store.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'chatgpt2api.bearerToken';

  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> writeToken(String token) => _storage.write(key: _tokenKey, value: token.trim());

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
```

- [ ] **Step 6: Implement server profile store**

Create `apps/image_studio_app/lib/core/storage/server_profile_store.dart`:

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ServerProfileStore {
  const ServerProfileStore(this._preferences);

  static const _activeProfileKey = 'chatgpt2api.activeServerProfile';

  final SharedPreferences _preferences;

  Uri? readActiveBaseUrl() {
    final raw = _preferences.getString(_activeProfileKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return Uri.tryParse(raw);
  }

  Future<void> writeActiveBaseUrl(Uri baseUrl) {
    return _preferences.setString(_activeProfileKey, _normalizeBaseUrl(baseUrl).toString());
  }

  Future<void> clearActiveBaseUrl() => _preferences.remove(_activeProfileKey);

  static Uri _normalizeBaseUrl(Uri value) {
    final normalized = value.replace(path: value.path.replaceAll(RegExp(r'/+$'), ''));
    return Uri.parse(jsonDecode(jsonEncode(normalized.toString())) as String);
  }
}
```

- [ ] **Step 7: Run core tests**

Run:

```bash
cd apps/image_studio_app && flutter test test/core/api_client_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit core layer**

Run:

```bash
git add apps/image_studio_app/lib/core apps/image_studio_app/test/core
git commit -m "feat: add flutter api client core"
```

## Task 5: Add Auth Flow

**Files:**
- Create: `apps/image_studio_app/lib/auth/auth_models.dart`
- Create: `apps/image_studio_app/lib/auth/auth_repository.dart`
- Create: `apps/image_studio_app/lib/auth/auth_controller.dart`
- Create: `apps/image_studio_app/lib/auth/onboarding_screen.dart`
- Create: `apps/image_studio_app/lib/auth/login_screen.dart`
- Create: `apps/image_studio_app/test/auth/auth_controller_test.dart`

- [ ] **Step 1: Write auth controller tests**

Create `apps/image_studio_app/test/auth/auth_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/auth/auth_controller.dart';
import 'package:image_studio_app/auth/auth_models.dart';

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
}
```

- [ ] **Step 2: Run the failing auth tests**

Run:

```bash
cd apps/image_studio_app && flutter test test/auth/auth_controller_test.dart
```

Expected: FAIL because auth files do not exist.

- [ ] **Step 3: Implement auth models**

Create `apps/image_studio_app/lib/auth/auth_models.dart`:

```dart
enum AuthRole { admin, user }

class AuthIdentity {
  const AuthIdentity({
    required this.id,
    required this.name,
    required this.role,
  });

  final String id;
  final String name;
  final AuthRole role;

  factory AuthIdentity.fromJson(Map<String, Object?> json) {
    return AuthIdentity(
      id: json['id'].toString(),
      name: json['name'].toString(),
      role: json['role'] == 'admin' ? AuthRole.admin : AuthRole.user,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.baseUrl,
    required this.token,
    required this.identity,
    required this.version,
    required this.capabilities,
  });

  final Uri baseUrl;
  final String token;
  final AuthIdentity identity;
  final String version;
  final List<String> capabilities;
}

class AuthState {
  const AuthState({
    this.session,
    this.loading = false,
    this.errorMessage,
  });

  final AuthSession? session;
  final bool loading;
  final String? errorMessage;

  AuthState copyWith({
    AuthSession? session,
    bool? loading,
    String? errorMessage,
    bool clearSession = false,
    bool clearError = false,
  }) {
    return AuthState(
      session: clearSession ? null : session ?? this.session,
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
```

- [ ] **Step 4: Implement repository contract and bearer-key login**

Create `apps/image_studio_app/lib/auth/auth_repository.dart`:

```dart
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
  })  : _tokenStore = tokenStore,
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
    final identity = AuthIdentity.fromJson(payload['identity']! as Map<String, Object?>);
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
```

- [ ] **Step 5: Implement auth controller**

Create `apps/image_studio_app/lib/auth/auth_controller.dart`:

```dart
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
```

- [ ] **Step 6: Add onboarding and login screens**

Create `apps/image_studio_app/lib/auth/onboarding_screen.dart` with a server URL field, connection copy, and CTA to login:

```dart
import 'package:flutter/material.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onContinue});

  final ValueChanged<Uri> onContinue;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: 'http://localhost:8000');
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Connect Image Studio', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                const Text('Enter your chatgpt2api backend URL. The app stores only the active server and bearer key.'),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'Backend URL'),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final uri = Uri.tryParse(controller.text.trim());
                    if (uri != null && uri.hasScheme) {
                      onContinue(uri);
                    }
                  },
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

Create `apps/image_studio_app/lib/auth/login_screen.dart` with a bearer key field:

```dart
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.baseUrl,
    required this.onLogin,
    this.loading = false,
    this.errorMessage,
  });

  final Uri baseUrl;
  final Future<void> Function(String bearerKey) onLogin;
  final bool loading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('API Key Mode', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(baseUrl.toString()),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Bearer key',
                    errorText: errorMessage,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: loading ? null : () => onLogin(controller.text.trim()),
                  child: Text(loading ? 'Connecting...' : 'Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Run auth tests**

Run:

```bash
cd apps/image_studio_app && flutter test test/auth/auth_controller_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit auth flow**

Run:

```bash
git add apps/image_studio_app/lib/auth apps/image_studio_app/test/auth
git commit -m "feat: add flutter bearer key auth flow"
```

## Task 6: Add Studio API Models and Repository

**Files:**
- Create: `apps/image_studio_app/lib/studio/studio_models.dart`
- Create: `apps/image_studio_app/lib/studio/studio_repository.dart`
- Create: `apps/image_studio_app/test/studio/studio_models_test.dart`

- [ ] **Step 1: Write model parsing tests**

Create `apps/image_studio_app/test/studio/studio_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/studio/studio_models.dart';

void main() {
  test('parses project response', () {
    final project = StudioProject.fromJson(<String, Object?>{
      'id': 'project-1',
      'name': 'Campaign',
      'owner_id': 'admin',
      'archived': false,
      'created_at': '2026-05-12T00:00:00Z',
      'updated_at': '2026-05-12T00:00:00Z',
    });

    expect(project.id, 'project-1');
    expect(project.name, 'Campaign');
    expect(project.archived, isFalse);
  });

  test('parses successful turn with result images', () {
    final turn = StudioTurn.fromJson(<String, Object?>{
      'id': 'turn-1',
      'conversation_id': 'conversation-1',
      'owner_id': 'admin',
      'client_task_id': 'task-1',
      'task_id': 'task-1',
      'mode': 'generate',
      'prompt': 'cat',
      'model': 'gpt-image-2',
      'size': '1024x1024',
      'reference_images': <Object?>[],
      'result_images': <Object?>[
        <String, Object?>{'url': 'http://localhost:8000/images/cat.png', 'path': '2026/05/cat.png'},
      ],
      'status': 'success',
      'error': '',
      'created_at': '2026-05-12T00:00:00Z',
      'updated_at': '2026-05-12T00:00:00Z',
    });

    expect(turn.status, StudioTurnStatus.success);
    expect(turn.resultImages.single.url.toString(), 'http://localhost:8000/images/cat.png');
  });
}
```

- [ ] **Step 2: Run the failing model tests**

Run:

```bash
cd apps/image_studio_app && flutter test test/studio/studio_models_test.dart
```

Expected: FAIL because studio models do not exist.

- [ ] **Step 3: Implement studio models**

Create `apps/image_studio_app/lib/studio/studio_models.dart`:

```dart
enum StudioTurnStatus { queued, running, success, error }

enum StudioTurnMode { generate, edit }

class StudioProject {
  const StudioProject({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String ownerId;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory StudioProject.fromJson(Map<String, Object?> json) {
    return StudioProject(
      id: json['id'].toString(),
      name: json['name'].toString(),
      ownerId: json['owner_id'].toString(),
      archived: json['archived'] == true,
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }
}

class StudioConversation {
  const StudioConversation({
    required this.id,
    required this.projectId,
    required this.title,
    required this.mode,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String title;
  final StudioTurnMode mode;
  final DateTime updatedAt;

  factory StudioConversation.fromJson(Map<String, Object?> json) {
    return StudioConversation(
      id: json['id'].toString(),
      projectId: json['project_id'].toString(),
      title: json['title'].toString(),
      mode: json['mode'] == 'edit' ? StudioTurnMode.edit : StudioTurnMode.generate,
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }
}

class StudioResultImage {
  const StudioResultImage({
    required this.url,
    required this.path,
  });

  final Uri url;
  final String path;

  factory StudioResultImage.fromJson(Map<String, Object?> json) {
    return StudioResultImage(
      url: Uri.parse(json['url'].toString()),
      path: (json['path'] ?? '').toString(),
    );
  }
}

class StudioTurn {
  const StudioTurn({
    required this.id,
    required this.conversationId,
    required this.clientTaskId,
    required this.taskId,
    required this.mode,
    required this.prompt,
    required this.model,
    required this.size,
    required this.resultImages,
    required this.status,
    required this.error,
    required this.updatedAt,
  });

  final String id;
  final String conversationId;
  final String clientTaskId;
  final String taskId;
  final StudioTurnMode mode;
  final String prompt;
  final String model;
  final String? size;
  final List<StudioResultImage> resultImages;
  final StudioTurnStatus status;
  final String error;
  final DateTime updatedAt;

  bool get isRunning => status == StudioTurnStatus.queued || status == StudioTurnStatus.running;

  factory StudioTurn.fromJson(Map<String, Object?> json) {
    return StudioTurn(
      id: json['id'].toString(),
      conversationId: json['conversation_id'].toString(),
      clientTaskId: json['client_task_id'].toString(),
      taskId: json['task_id'].toString(),
      mode: json['mode'] == 'edit' ? StudioTurnMode.edit : StudioTurnMode.generate,
      prompt: json['prompt'].toString(),
      model: json['model'].toString(),
      size: json['size']?.toString(),
      resultImages: ((json['result_images'] ?? <Object?>[]) as List)
          .cast<Map<String, Object?>>()
          .map(StudioResultImage.fromJson)
          .toList(),
      status: switch (json['status']) {
        'running' => StudioTurnStatus.running,
        'success' => StudioTurnStatus.success,
        'error' => StudioTurnStatus.error,
        _ => StudioTurnStatus.queued,
      },
      error: (json['error'] ?? '').toString(),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }
}
```

- [ ] **Step 4: Implement studio repository**

Create `apps/image_studio_app/lib/studio/studio_repository.dart`:

```dart
import '../core/api/api_client.dart';
import 'studio_models.dart';

class StudioRepository {
  const StudioRepository(this._client);

  final ApiClient _client;

  Future<List<StudioProject>> fetchProjects() async {
    final payload = await _client.getJson('/api/projects');
    return _items(payload).map(StudioProject.fromJson).toList();
  }

  Future<StudioProject> createProject(String name) async {
    final payload = await _client.postJson('/api/projects', body: <String, Object?>{'name': name});
    return StudioProject.fromJson(payload['item']! as Map<String, Object?>);
  }

  Future<List<StudioConversation>> fetchConversations(String projectId) async {
    final payload = await _client.getJson('/api/image-conversations', query: <String, Object?>{'project_id': projectId});
    return _items(payload).map(StudioConversation.fromJson).toList();
  }

  Future<List<StudioTurn>> fetchTurns(String conversationId) async {
    final payload = await _client.getJson('/api/image-turns', query: <String, Object?>{'conversation_id': conversationId});
    return _items(payload).map(StudioTurn.fromJson).toList();
  }

  Future<StudioTurn> createGenerationTurn({
    required String conversationId,
    required String clientTaskId,
    required String prompt,
    required String model,
    String? size,
  }) async {
    final payload = await _client.postJson(
      '/api/image-turns/generations',
      body: <String, Object?>{
        'conversation_id': conversationId,
        'client_task_id': clientTaskId,
        'prompt': prompt,
        'model': model,
        if (size != null) 'size': size,
      },
    );
    return StudioTurn.fromJson(payload['item']! as Map<String, Object?>);
  }

  Future<StudioTurn> syncTurn(String turnId) async {
    final payload = await _client.postJson('/api/image-turns/$turnId/sync');
    return StudioTurn.fromJson(payload['item']! as Map<String, Object?>);
  }

  List<Map<String, Object?>> _items(Map<String, Object?> payload) {
    return (payload['items']! as List).cast<Map<String, Object?>>();
  }
}
```

- [ ] **Step 5: Run model tests**

Run:

```bash
cd apps/image_studio_app && flutter test test/studio/studio_models_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit studio API layer**

Run:

```bash
git add apps/image_studio_app/lib/studio/studio_models.dart apps/image_studio_app/lib/studio/studio_repository.dart apps/image_studio_app/test/studio/studio_models_test.dart
git commit -m "feat: add flutter studio api models"
```

## Task 7: Add Studio State Controller and Polling

**Files:**
- Create: `apps/image_studio_app/lib/studio/studio_controller.dart`
- Create: `apps/image_studio_app/test/studio/studio_controller_test.dart`

- [ ] **Step 1: Write polling tests**

Create `apps/image_studio_app/test/studio/studio_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/studio/studio_controller.dart';
import 'package:image_studio_app/studio/studio_models.dart';

void main() {
  test('polling stops after turn reaches terminal state', () async {
    final repository = FakeStudioRepository();
    final controller = StudioController(repository);

    controller.replaceTurns([
      fakeTurn(status: StudioTurnStatus.running),
    ]);
    await controller.pollRunningTurnsOnce();

    expect(controller.state.turns.single.status, StudioTurnStatus.success);
    expect(controller.hasRunningTurns, isFalse);
  });

  test('draft is preserved when submit fails', () async {
    final repository = FakeStudioRepository()..failSubmit = true;
    final controller = StudioController(repository);

    await expectLater(
      controller.submitGeneration(
        conversationId: 'conversation-1',
        prompt: 'a red cabin',
      ),
      throwsA(isA<Exception>()),
    );

    expect(controller.state.promptDraft, 'a red cabin');
  });
}

class FakeStudioRepository implements StudioRepositoryContract {
  bool failSubmit = false;

  @override
  Future<StudioTurn> createGenerationTurn({
    required String conversationId,
    required String clientTaskId,
    required String prompt,
    required String model,
    String? size,
  }) async {
    if (failSubmit) {
      throw Exception('network down');
    }
    return fakeTurn(status: StudioTurnStatus.running);
  }

  @override
  Future<StudioTurn> syncTurn(String turnId) async {
    return fakeTurn(status: StudioTurnStatus.success);
  }
}

StudioTurn fakeTurn({required StudioTurnStatus status}) {
  return StudioTurn(
    id: 'turn-1',
    conversationId: 'conversation-1',
    clientTaskId: 'task-1',
    taskId: 'task-1',
    mode: StudioTurnMode.generate,
    prompt: 'cat',
    model: 'gpt-image-2',
    size: '1024x1024',
    resultImages: const [],
    status: status,
    error: '',
    updatedAt: DateTime.utc(2026, 5, 12),
  );
}
```

- [ ] **Step 2: Run the failing polling tests**

Run:

```bash
cd apps/image_studio_app && flutter test test/studio/studio_controller_test.dart
```

Expected: FAIL because `StudioController` does not exist.

- [ ] **Step 3: Add repository contract**

In `apps/image_studio_app/lib/studio/studio_repository.dart`, add:

```dart
abstract interface class StudioRepositoryContract {
  Future<StudioTurn> createGenerationTurn({
    required String conversationId,
    required String clientTaskId,
    required String prompt,
    required String model,
    String? size,
  });

  Future<StudioTurn> syncTurn(String turnId);
}
```

Change `class StudioRepository` to:

```dart
class StudioRepository implements StudioRepositoryContract {
```

- [ ] **Step 4: Implement controller**

Create `apps/image_studio_app/lib/studio/studio_controller.dart`:

```dart
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

  bool get hasRunningTurns => _state.turns.any((turn) => turn.isRunning);

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
    _state = _state.copyWith(promptDraft: prompt, submitting: true, clearError: true);
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
```

- [ ] **Step 5: Run controller tests**

Run:

```bash
cd apps/image_studio_app && flutter test test/studio/studio_controller_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit controller**

Run:

```bash
git add apps/image_studio_app/lib/studio/studio_controller.dart apps/image_studio_app/lib/studio/studio_repository.dart apps/image_studio_app/test/studio/studio_controller_test.dart
git commit -m "feat: add studio controller polling"
```

## Task 8: Add Adaptive App Shell and Routing

**Files:**
- Modify: `apps/image_studio_app/lib/main.dart`
- Create: `apps/image_studio_app/lib/app/image_studio_app.dart`
- Create: `apps/image_studio_app/lib/app/router.dart`
- Create: `apps/image_studio_app/lib/app/theme.dart`
- Create: `apps/image_studio_app/lib/app/responsive.dart`
- Create: `apps/image_studio_app/lib/shared/adaptive_shell.dart`
- Create: `apps/image_studio_app/test/shared/adaptive_shell_test.dart`

- [ ] **Step 1: Write adaptive shell widget tests**

Create `apps/image_studio_app/test/shared/adaptive_shell_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/shared/adaptive_shell.dart';

void main() {
  testWidgets('compact width uses bottom navigation', (tester) async {
    await tester.pumpWidget(_host(width: 390));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('expanded width uses three panes', (tester) async {
    await tester.pumpWidget(_host(width: 1280));

    expect(find.byKey(const ValueKey('desktop-project-pane')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-center-pane')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-inspector-pane')), findsOneWidget);
  });
}

Widget _host({required double width}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 900)),
      child: const AdaptiveShell(
        selectedIndex: 0,
        onDestinationSelected: _ignore,
        create: Text('Create'),
        library: Text('Library'),
        projects: Text('Projects'),
        settings: Text('Settings'),
      ),
    ),
  );
}

void _ignore(int _) {}
```

- [ ] **Step 2: Run the failing adaptive tests**

Run:

```bash
cd apps/image_studio_app && flutter test test/shared/adaptive_shell_test.dart
```

Expected: FAIL because `AdaptiveShell` does not exist.

- [ ] **Step 3: Implement responsive helpers**

Create `apps/image_studio_app/lib/app/responsive.dart`:

```dart
import 'package:flutter/widgets.dart';

enum WindowClass { compact, medium, expanded }

WindowClass windowClassOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1100) {
    return WindowClass.expanded;
  }
  if (width >= 720) {
    return WindowClass.medium;
  }
  return WindowClass.compact;
}
```

- [ ] **Step 4: Implement adaptive shell**

Create `apps/image_studio_app/lib/shared/adaptive_shell.dart`:

```dart
import 'package:flutter/material.dart';

import '../app/responsive.dart';

class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.create,
    required this.library,
    required this.projects,
    required this.settings,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget create;
  final Widget library;
  final Widget projects;
  final Widget settings;

  @override
  Widget build(BuildContext context) {
    final pages = [create, library, projects, settings];
    return switch (windowClassOf(context)) {
      WindowClass.compact => Scaffold(
          body: pages[selectedIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'Create'),
              NavigationDestination(icon: Icon(Icons.photo_library_outlined), label: 'Library'),
              NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Projects'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
            ],
          ),
        ),
      WindowClass.medium => Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.auto_awesome), label: Text('Create')),
                NavigationRailDestination(icon: Icon(Icons.photo_library_outlined), label: Text('Library')),
                NavigationRailDestination(icon: Icon(Icons.folder_outlined), label: Text('Projects')),
                NavigationRailDestination(icon: Icon(Icons.settings_outlined), label: Text('Settings')),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: pages[selectedIndex]),
          ],
        ),
      WindowClass.expanded => Row(
          children: [
            SizedBox(key: const ValueKey('desktop-project-pane'), width: 280, child: projects),
            const VerticalDivider(width: 1),
            Expanded(key: const ValueKey('desktop-center-pane'), child: create),
            const VerticalDivider(width: 1),
            SizedBox(key: const ValueKey('desktop-inspector-pane'), width: 340, child: library),
          ],
        ),
    };
  }
}
```

- [ ] **Step 5: Add app theme**

Create `apps/image_studio_app/lib/app/theme.dart`:

```dart
import 'package:flutter/material.dart';

ThemeData buildImageStudioTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFE8A84A),
    brightness: Brightness.dark,
  );
  return ThemeData(
    colorScheme: scheme,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF15120E),
    useMaterial3: true,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      filled: true,
    ),
  );
}
```

- [ ] **Step 6: Add root app and router skeleton**

Create `apps/image_studio_app/lib/app/router.dart`:

```dart
import 'package:go_router/go_router.dart';

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
        builder: (context, state) => LoginScreenPlaceholder(baseUrl: pendingBaseUrl ?? Uri.parse('http://localhost:8000')),
      ),
      GoRoute(
        path: '/studio',
        builder: (context, state) => const CreateScreen(),
      ),
    ],
  );
}
```

Create `apps/image_studio_app/lib/app/image_studio_app.dart`:

```dart
import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class ImageStudioApp extends StatelessWidget {
  const ImageStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Image Studio',
      theme: buildImageStudioTheme(),
      routerConfig: buildRouter(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

Modify `apps/image_studio_app/lib/main.dart`:

```dart
import 'package:flutter/material.dart';

import 'app/image_studio_app.dart';

void main() {
  runApp(const ImageStudioApp());
}
```

- [ ] **Step 7: Run adaptive tests**

Run:

```bash
cd apps/image_studio_app && flutter test test/shared/adaptive_shell_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit shell and routing**

Run:

```bash
git add apps/image_studio_app/lib/app apps/image_studio_app/lib/main.dart apps/image_studio_app/lib/shared/adaptive_shell.dart apps/image_studio_app/test/shared/adaptive_shell_test.dart
git commit -m "feat: add adaptive flutter app shell"
```

## Task 9: Add Create, Project, Library, and Settings Screens

**Files:**
- Create: `apps/image_studio_app/lib/studio/create_screen.dart`
- Create: `apps/image_studio_app/lib/studio/projects_screen.dart`
- Create: `apps/image_studio_app/lib/studio/turn_detail_screen.dart`
- Create: `apps/image_studio_app/lib/library/library_screen.dart`
- Create: `apps/image_studio_app/lib/settings/settings_screen.dart`
- Create: `apps/image_studio_app/lib/shared/image_result_card.dart`
- Create: `apps/image_studio_app/lib/shared/empty_state.dart`
- Create: `apps/image_studio_app/test/studio/create_screen_test.dart`

- [ ] **Step 1: Write composer widget tests**

Create `apps/image_studio_app/test/studio/create_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/studio/create_screen.dart';

void main() {
  testWidgets('generate button is disabled when prompt is empty', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CreateScreen()));

    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Generate'));
    expect(button.onPressed, isNull);
  });

  testWidgets('generate button is enabled when prompt has text', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CreateScreen()));

    await tester.enterText(find.byType(TextField), 'paint a glass fox');
    await tester.pump();

    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Generate'));
    expect(button.onPressed, isNotNull);
  });
}
```

- [ ] **Step 2: Run the failing screen test**

Run:

```bash
cd apps/image_studio_app && flutter test test/studio/create_screen_test.dart
```

Expected: FAIL because `CreateScreen` does not exist.

- [ ] **Step 3: Implement empty state**

Create `apps/image_studio_app/lib/shared/empty_state.dart`:

```dart
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement image result card**

Create `apps/image_studio_app/lib/shared/image_result_card.dart`:

```dart
import 'package:flutter/material.dart';

class ImageResultCard extends StatelessWidget {
  const ImageResultCard({
    super.key,
    required this.imageUrl,
    required this.onFavorite,
    required this.onContinueEdit,
  });

  final Uri imageUrl;
  final VoidCallback onFavorite;
  final VoidCallback onContinueEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Image.network(
              imageUrl.toString(),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
          ButtonBar(
            alignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: onFavorite, icon: const Icon(Icons.star_border)),
              TextButton(onPressed: onContinueEdit, child: const Text('Continue edit')),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Implement create screen**

Create `apps/image_studio_app/lib/studio/create_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../shared/empty_state.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _promptController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPrompt = _promptController.text.trim().isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _promptController,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Prompt',
                  hintText: 'Describe the image you want to create',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: hasPrompt ? () {} : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate'),
              ),
              const Expanded(
                child: EmptyState(
                  title: 'No active results',
                  message: 'Generate an image to start a visual conversation.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Add project, library, detail, settings placeholders**

Create `apps/image_studio_app/lib/studio/projects_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../shared/empty_state.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'Projects',
      message: 'Project and conversation switching will appear here.',
    );
  }
}
```

Create `apps/image_studio_app/lib/studio/turn_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../shared/empty_state.dart';

class TurnDetailScreen extends StatelessWidget {
  const TurnDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'Turn detail',
      message: 'Prompt, status, result images, retry, and continue edit actions will appear here.',
    );
  }
}
```

Create `apps/image_studio_app/lib/library/library_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../shared/empty_state.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'Library',
      message: 'Recent and favorite generated images will appear here.',
    );
  }
}
```

Create `apps/image_studio_app/lib/settings/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../shared/empty_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'Settings',
      message: 'Server, session, cache, and sign-out controls will appear here.',
    );
  }
}
```

- [ ] **Step 7: Run screen tests**

Run:

```bash
cd apps/image_studio_app && flutter test test/studio/create_screen_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit screens**

Run:

```bash
git add apps/image_studio_app/lib/studio apps/image_studio_app/lib/library apps/image_studio_app/lib/settings apps/image_studio_app/lib/shared apps/image_studio_app/test/studio/create_screen_test.dart
git commit -m "feat: add flutter image studio screens"
```

## Task 10: Wire Screens to Real Studio Data

**Files:**
- Modify: `apps/image_studio_app/lib/app/router.dart`
- Modify: `apps/image_studio_app/lib/studio/create_screen.dart`
- Modify: `apps/image_studio_app/lib/studio/projects_screen.dart`
- Modify: `apps/image_studio_app/lib/library/library_screen.dart`
- Modify: `apps/image_studio_app/lib/settings/settings_screen.dart`
- Modify: `apps/image_studio_app/lib/studio/studio_repository.dart`
- Modify: `apps/image_studio_app/lib/studio/studio_controller.dart`

- [ ] **Step 1: Add missing repository methods for projects and favorites**

In `apps/image_studio_app/lib/studio/studio_repository.dart`, add methods for:

```dart
Future<StudioConversation> createConversation({
  required String projectId,
  required String title,
  String mode = 'generate',
});

Future<List<StudioFavorite>> fetchFavorites();

Future<StudioFavorite> favoriteImage({
  required String imagePath,
  String sourceTurnId = '',
});

Future<void> deleteFavorite(String favoriteId);
```

Use these backend routes:

```text
POST /api/image-conversations
GET /api/image-favorites
POST /api/image-favorites
DELETE /api/image-favorites/{favorite_id}
```

- [ ] **Step 2: Add `StudioFavorite` model**

In `apps/image_studio_app/lib/studio/studio_models.dart`, add:

```dart
class StudioFavorite {
  const StudioFavorite({
    required this.id,
    required this.imagePath,
    required this.sourceTurnId,
    required this.createdAt,
  });

  final String id;
  final String imagePath;
  final String sourceTurnId;
  final DateTime createdAt;

  factory StudioFavorite.fromJson(Map<String, Object?> json) {
    return StudioFavorite(
      id: json['id'].toString(),
      imagePath: json['image_path'].toString(),
      sourceTurnId: (json['source_turn_id'] ?? '').toString(),
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }
}
```

- [ ] **Step 3: Load first project and conversation after login**

In `StudioController`, add a `loadWorkspace()` method that:

```dart
Future<void> loadWorkspace() async {
  final projects = await _repository.fetchProjects();
  final activeProject = projects.isNotEmpty ? projects.first : await _repository.createProject('Untitled Project');
  final conversations = await _repository.fetchConversations(activeProject.id);
  final activeConversation = conversations.isNotEmpty
      ? conversations.first
      : await _repository.createConversation(projectId: activeProject.id, title: 'New image session');
  final turns = await _repository.fetchTurns(activeConversation.id);
  _state = _state.copyWith(turns: turns);
  notifyListeners();
}
```

- [ ] **Step 4: Wire create screen submission**

Update `CreateScreen` so the Generate button calls:

```dart
await controller.submitGeneration(
  conversationId: activeConversationId,
  prompt: _promptController.text.trim(),
);
```

After successful submit, start a periodic poll every 2 seconds while `controller.hasRunningTurns` is true.

- [ ] **Step 5: Wire library favorites**

Update `LibraryScreen` to:

```dart
final favorites = await repository.fetchFavorites();
```

Render favorites with `ImageResultCard`, resolving image URLs relative to the active server base URL when the backend returns only `image_path`.

- [ ] **Step 6: Wire settings sign-out**

Update `SettingsScreen` to call:

```dart
await authController.signOut();
```

After sign-out, route to `/`.

- [ ] **Step 7: Run full Flutter tests**

Run:

```bash
cd apps/image_studio_app && flutter test
```

Expected: PASS.

- [ ] **Step 8: Commit data wiring**

Run:

```bash
git add apps/image_studio_app/lib apps/image_studio_app/test
git commit -m "feat: wire flutter studio screens to api"
```

## Task 11: Add Flutter GitHub Actions Builds

**Files:**
- Create: `.github/workflows/flutter-app.yml`

- [ ] **Step 1: Create workflow**

Create `.github/workflows/flutter-app.yml`:

```yaml
name: Flutter Image Studio

on:
  push:
    branches:
      - main
      - "codex/**"
  pull_request:

jobs:
  analyze-test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: apps/image_studio_app
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: dart format --set-exit-if-changed lib test
      - run: flutter analyze
      - run: flutter test

  build-android:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: apps/image_studio_app
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter build apk --debug
      - uses: actions/upload-artifact@v4
        with:
          name: image-studio-android-debug-apk
          path: apps/image_studio_app/build/app/outputs/flutter-apk/app-debug.apk

  build-linux:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: apps/image_studio_app
    steps:
      - uses: actions/checkout@v4
      - run: sudo apt-get update
      - run: sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter config --enable-linux-desktop
      - run: flutter pub get
      - run: flutter build linux --debug
      - uses: actions/upload-artifact@v4
        with:
          name: image-studio-linux-debug
          path: apps/image_studio_app/build/linux/x64/debug/bundle

  build-windows:
    runs-on: windows-latest
    defaults:
      run:
        working-directory: apps/image_studio_app
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter config --enable-windows-desktop
      - run: flutter pub get
      - run: flutter build windows --debug
      - uses: actions/upload-artifact@v4
        with:
          name: image-studio-windows-debug
          path: apps/image_studio_app/build/windows/x64/runner/Debug

  build-apple:
    runs-on: macos-latest
    defaults:
      run:
        working-directory: apps/image_studio_app
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter config --enable-macos-desktop
      - run: flutter pub get
      - run: flutter build macos --debug
      - run: flutter build ios --debug --no-codesign
      - uses: actions/upload-artifact@v4
        with:
          name: image-studio-macos-debug
          path: apps/image_studio_app/build/macos/Build/Products/Debug
```

- [ ] **Step 2: Validate workflow syntax locally if available**

Run:

```bash
git diff --check .github/workflows/flutter-app.yml
```

Expected: no whitespace errors.

- [ ] **Step 3: Commit CI workflow**

Run:

```bash
git add .github/workflows/flutter-app.yml
git commit -m "ci: build flutter image studio app"
```

## Task 12: Final Verification and Push

**Files:**
- Verify all changed files.

- [ ] **Step 1: Run backend tests**

Run:

```bash
uv run python -m unittest test.test_studio_service test.test_studio_api test.test_app_bootstrap_api test.test_image_tasks_api test.test_image_task_service -v
```

Expected: PASS.

- [ ] **Step 2: Run Flutter checks**

Run:

```bash
cd apps/image_studio_app && dart format --set-exit-if-changed lib test && flutter analyze && flutter test
```

Expected: PASS.

- [ ] **Step 3: Build at least one local app target**

Run:

```bash
cd apps/image_studio_app && flutter build apk --debug
```

Expected: PASS and `build/app/outputs/flutter-apk/app-debug.apk` exists.

- [ ] **Step 4: Check git status**

Run:

```bash
git status --short --branch
```

Expected: clean except for intentional untracked local files such as `AGENTS.md`.

- [ ] **Step 5: Push branch to fork**

Run:

```bash
git push origin codex/flutter-image-studio-app
```

Expected: push succeeds to `https://github.com/jeck5001/chatgpt2api`.

---

## Self-Review

Spec coverage:

- Flutter cross-platform client is covered by Tasks 3, 8, 9, 10, and 11.
- iOS, Android, macOS, Windows, and Linux builds are covered by Task 11.
- FastAPI source of truth and server-backed studio APIs are covered by Tasks 1 and 2.
- API key / bearer key mode is covered by Tasks 2, 4, and 5.
- Username/password login is intentionally not implemented because the current backend only exposes bearer-key validation.
- Online-only behavior and prompt draft preservation are covered by Task 7.
- Mobile bottom tabs, tablet two-pane behavior, and desktop three-pane behavior are covered by Task 8.
- Project, conversation, turn, favorite, library, and settings flows are covered by Tasks 6, 9, and 10.
- CI build artifacts are covered by Task 11.

Placeholder scan:

- No `TBD`, `TODO`, or undefined “implement later” steps remain.
- Each task includes concrete file paths, commands, expected outcomes, and commit points.

Type consistency:

- `StudioProject`, `StudioConversation`, `StudioTurn`, `StudioFavorite`, `AuthSession`, and `AuthIdentity` names are consistent across tests, repositories, and controllers.
- Backend route names match `api/studio.py` from the existing `codex/internal-image-studio` worktree and the cross-platform design spec.
