/// Sign-in flow state — SRS §4.1 (FR-001, FR-008, SEC-ID-06).
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
  const AuthAuthenticated({required this.accessToken, this.displayName});

  /// In-memory only — never persisted (SEC-ID-05).
  final String accessToken;

  /// From `GET /api/me`; null if that call hasn't succeeded (e.g. the
  /// backend isn't reachable) — sign-in via ThunderID still counts.
  final String? displayName;
}

class AuthError extends AuthState {
  const AuthError(this.message);

  final String message;
}
