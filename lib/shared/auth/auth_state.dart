/// Sign-in flow state.
sealed class AuthState {
  const AuthState();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticating extends AuthState {
  const AuthAuthenticating();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({
    required this.accessToken,
    this.userId,
    this.email,
    this.displayName,
    this.role,
    this.profileError,
  });

  /// In-memory only — never persisted.
  final String accessToken;

  /// From `GET /api/me`.
  final String? userId;
  final String? email;

  /// From `GET /api/me`.
  final String? displayName;

  /// `Staff` or `InventoryOfficer`.
  final String? role;

  /// Why `GET /api/me` failed, when it did — shown on the dashboard in place
  /// of the role-specific content. Never contains a token.
  final String? profileError;
}

/// Signed in, but role is not supported by mobile app.
class AuthRoleNotSupported extends AuthState {
  const AuthRoleNotSupported(this.role);

  final String role;
}

class AuthError extends AuthState {
  const AuthError(this.message);

  final String message;
}
