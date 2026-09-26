import 'package:dio/dio.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
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

  /// For the two calls made outside the authenticated [apiClientProvider]
  /// (`/api/me` with a just-issued token, and token revocation). Bounded
  /// timeouts so an unreachable backend or ThunderID can't leave sign-in or
  /// sign-out spinning indefinitely.
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

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
          // `roles` plus the profile/email claims are what the backend needs
          // to recognise (or first-time provision) the CoreGrid user behind
          // this token — without them every API call, `/api/me` included,
          // is rejected 401 (RoleEnrichmentMiddleware.cs).
          scopes: const ['openid', 'profile', 'email', 'roles'],
        ),
      );

      final accessToken = result.accessToken;
      if (accessToken == null) {
        state = const AuthError('ThunderID did not return an access token.');
        return;
      }

      final (:profile, :error) = await _fetchProfile(accessToken);

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
        profileError: error,
      );
    } on FlutterAppAuthUserCancelledException {
      state = const AuthUnauthenticated();
    } catch (e) {
      state = AuthError('Sign-in failed: $e');
    }
  }

  /// FR-008: sign-out must terminate the identity-provider session, not just
  /// clear local state — otherwise the stored refresh token would remain
  /// valid if it ever leaked. Revokes it via ThunderID's RFC 7009 endpoint
  /// (`oauth2/revoke`, from the discovery document) before clearing local
  /// storage. Best-effort: revocation failing (offline, ThunderID down)
  /// still signs the user out locally — SEC-ID-05 cares that no token is
  /// logged or left in shared storage, not that revocation is guaranteed.
  Future<void> signOut() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken != null && AuthConfig.thunderIdIssuer.isNotEmpty) {
      try {
        await _dio.post<void>(
          '${AuthConfig.thunderIdIssuer}/oauth2/revoke',
          data: {
            'token': refreshToken,
            'token_type_hint': 'refresh_token',
            'client_id': AuthConfig.thunderIdClientId,
          },
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            validateStatus: (_) => true,
          ),
        );
      } catch (_) {
        // Offline or ThunderID unreachable — local sign-out still proceeds.
      }
    }

    await _tokenStorage.clear();
    state = const AuthUnauthenticated();
  }

  /// Best-effort `GET /api/me` — a failure here (e.g. the backend isn't
  /// running) doesn't undo a successful ThunderID sign-in; role-gating simply
  /// doesn't apply until the role is known, and the reason is returned as
  /// `error` so the dashboard can say why instead of guessing. `role` is CoreGrid's own
  /// `Users.Role` column, not a ThunderID token claim (see `MeController.cs`
  /// — deliberately decoupled from ThunderID's claim wiring, same as React).
  Future<({({String? displayName, String role})? profile, String? error})>
  _fetchProfile(String accessToken) async {
    if (AuthConfig.apiBaseUrl.isEmpty) {
      return (profile: null, error: 'API_BASE_URL is not configured.');
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${AuthConfig.apiOrigin}/api/me',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final data = response.data;
      final role = data?['role']?.toString();
      if (data == null || role == null) {
        return (profile: null, error: 'CoreGrid returned no role for you.');
      }
      return (
        profile: (
          displayName: (data['given_name'] ?? data['email'])?.toString(),
          role: role,
        ),
        error: null,
      );
    } on DioException catch (e) {
      final apiError = ApiException.fromDio(e);
      return (
        profile: null,
        error: apiError.isUnauthorized
            ? 'CoreGrid rejected your sign-in (401): no active CoreGrid user '
                  'matches this ThunderID account. Check the account has a '
                  'CoreGrid role assigned and that the mobile app\'s access '
                  'token includes email, given_name, family_name and roles.'
            : apiError.message,
      );
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
