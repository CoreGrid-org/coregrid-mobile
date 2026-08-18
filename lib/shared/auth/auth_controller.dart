import 'package:dio/dio.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_config.dart';
import 'auth_state.dart';
import 'token_storage.dart';

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

      final refreshToken = result.refreshToken;
      if (refreshToken != null) {
        await _tokenStorage.saveRefreshToken(refreshToken);
      }

      state = AuthAuthenticated(
        accessToken: accessToken,
        displayName: await _fetchDisplayName(accessToken),
      );
    } on FlutterAppAuthUserCancelledException {
      state = const AuthUnauthenticated();
    } catch (e) {
      state = AuthError('Sign-in failed: $e');
    }
  }

  Future<void> signOut() async {
    await _tokenStorage.clear();
    state = const AuthUnauthenticated();
  }

  /// Best-effort `GET /api/me` — a failure here (e.g. the backend isn't
  /// running) doesn't undo a successful ThunderID sign-in.
  Future<String?> _fetchDisplayName(String accessToken) async {
    if (AuthConfig.apiBaseUrl.isEmpty) return null;
    try {
      final response = await Dio().get<Map<String, dynamic>>(
        '${AuthConfig.apiBaseUrl}/api/me',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final data = response.data;
      if (data == null) return null;
      return (data['displayName'] ?? data['email'])?.toString();
    } catch (_) {
      return null;
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
