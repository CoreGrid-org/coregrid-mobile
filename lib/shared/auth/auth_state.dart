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
  const AuthAuthenticated({
    required this.accessToken,
    this.displayName,
    this.role,
  });

  /// In-memory only — never persisted (SEC-ID-05).
  final String accessToken;

  /// From `GET /api/me`; null if that call hasn't succeeded (e.g. the
  /// backend isn't reachable) — sign-in via ThunderID still counts.
  final String? displayName;

  /// `Staff` or `InventoryOfficer` — the only roles that reach this state
  /// (see [AuthRoleNotSupported]). Null only if `/api/me` hasn't resolved
  /// yet; drives which dashboard `features/dashboard/` shows.
  final String? role;
}

/// ThunderID accepted the sign-in, but `GET /api/me` reports a role this app
/// doesn't serve — Auditor and Administrator are web-console-only (SRS §3.4:
/// "React is the management and control interface; Flutter is the field
/// operations interface"), mirrored from FR-059/067/069's scope change.
/// The refresh token is cleared immediately (see [AuthController.signIn]) —
/// an unsupported role never counts as a real mobile session.
class AuthRoleNotSupported extends AuthState {
  const AuthRoleNotSupported(this.role);

  final String role;
}

class AuthError extends AuthState {
  const AuthError(this.message);

  final String message;
}
