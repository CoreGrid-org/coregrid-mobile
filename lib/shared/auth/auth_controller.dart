import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_config.dart';
import 'auth_state.dart';
import 'token_storage.dart';

/// Roles this app serves — Officer (field work) and Staff (local work).
/// Auditor and Administrator are web-console-only (see [AuthRoleNotSupported]).
/// Matches `CoreGridRole` in the backend (`backend/Domain/Identity/CoreGridRole.cs`).
const kMobileSupportedRoles = {'Staff', 'InventoryOfficer'};

/// Human-readable role name, matching the exact wording used throughout the
/// main SRS (`CoreGrid/doc/SRS/02-overall-description.md` §2.3.1) rather than
/// the raw `CoreGridRole` enum spelling.
String roleLabel(String role) =>
    role == 'InventoryOfficer' ? 'Inventory Officer' : role;

/// Drives the ThunderID Authorization Code + PKCE flow (SRS §4.1, SEC-ID-06)
/// via `flutter_appauth`, which uses Chrome Custom Tabs on Android — an
/// external user agent per RFC 8252, not an embedded WebView, so this stays
/// compliant while still feeling like part of the app rather than a
/// browser-switch.
class AuthController extends Notifier<AuthState> {
  final _appAuth = const FlutterAppAuth();
  final _tokenStorage = TokenStorage();

  @override
  AuthState build() => const AuthUnauthenticated();

  Future<void> signIn() async {
    if (!AuthConfig.isConfigured) {
      state = const AuthError(
        'App isn\'t configured with ThunderID/API values — pass '
        '--dart-define-from-file (see CONTRIBUTING.md).',
      );
      return;
    }

    state = const AuthAuthenticating();
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AuthConfig.thunderIdClientId,
          AuthConfig.redirectUrl,
          issuer: AuthConfig.thunderIdIssuer,
          scopes: const ['openid', 'profile', 'email'],
        ),
      );

      final accessToken = result.accessToken;
      if (accessToken == null) {
        state = const AuthError('ThunderID did not return an access token.');
        return;
      }

      final profile = await _fetchProfile(accessToken);

      if (profile != null && !kMobileSupportedRoles.contains(profile.role)) {
        await _tokenStorage.clear();
        state = AuthRoleNotSupported(profile.role);
        return;
      }

      final refreshToken = result.refreshToken;
      if (refreshToken != null) {
        await _tokenStorage.saveRefreshToken(refreshToken);
      }

      state = AuthAuthenticated(
        accessToken: accessToken,
        displayName: profile?.displayName,
        role: profile?.role,
      );
    } on FlutterAppAuthUserCancelledException {
      state = const AuthUnauthenticated();
    } catch (e) {
      state = AuthError('Sign-in failed: $e');
    }
  }

  /// Debug-only bypass of the ThunderID PKCE flow — jumps straight to the
  /// dashboard as the given role, without a running ThunderID instance or
  /// backend. The picker only offers [kMobileSupportedRoles] (Staff,
  /// Inventory Officer) since Auditor/Administrator never reach this app for
  /// real; the unsupported-role branch below is kept only as a safety net if
  /// this is ever called with something else. `kDebugMode` is a compile-time
  /// constant (`false` in release/profile builds), so the guarded branch is
  /// dead-code-eliminated from any real build — this can never ship. No
  /// token is persisted: the access token is an obvious placeholder, never a
  /// real bearer credential.
  void devSignIn(String role) {
    if (!kDebugMode) return;
    state = kMobileSupportedRoles.contains(role)
        ? AuthAuthenticated(
            accessToken: 'dev-bypass-token',
            displayName: roleLabel(role),
            role: role,
          )
        : AuthRoleNotSupported(role);
  }

  Future<void> signOut() async {
    await _tokenStorage.clear();
    state = const AuthUnauthenticated();
  }

  /// Best-effort `GET /api/me` — a failure here (e.g. the backend isn't
  /// running) doesn't undo a successful ThunderID sign-in; role-gating simply
  /// doesn't apply until the role is known. `role` is CoreGrid's own
  /// `Users.Role` column, not a ThunderID token claim (see `MeController.cs`
  /// — deliberately decoupled from ThunderID's claim wiring, same as React).
  Future<({String? displayName, String role})?> _fetchProfile(
    String accessToken,
  ) async {
    if (AuthConfig.apiBaseUrl.isEmpty) return null;
    try {
      final response = await Dio().get<Map<String, dynamic>>(
        '${AuthConfig.apiBaseUrl}/api/me',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final data = response.data;
      final role = data?['role']?.toString();
      if (data == null || role == null) return null;
      return (
        displayName: (data['given_name'] ?? data['email'])?.toString(),
        role: role,
      );
    } catch (_) {
      return null;
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
