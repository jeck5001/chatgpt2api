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
