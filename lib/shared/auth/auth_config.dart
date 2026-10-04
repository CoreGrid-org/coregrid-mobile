/// Environment configuration for auth and the API client, read via
/// `--dart-define` (or `--dart-define-from-file`) — never hardcoded, never
/// committed (`doc/mobile-specification.md` §5.1).
abstract final class AuthConfig {
  /// CoreGrid backend base URL, e.g. `http://localhost:5083`.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// [apiBaseUrl] as a bare origin. Every call in the app prefixes `/api/...`
  /// itself, so a trailing `/` or an accidentally-appended `/api` (a common
  /// run-command slip that silently produces `/api/api/...` → 404) is
  /// stripped here.
  static String get apiOrigin {
    var url = apiBaseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/api')) {
      url = url.substring(0, url.length - '/api'.length);
    }
    return url;
  }

  /// ThunderID's bare issuer URL (no path) — OIDC discovery is resolved from
  /// this automatically. e.g. `https://localhost:8090`.
  static const String thunderIdIssuer = String.fromEnvironment(
    'THUNDERID_ISSUER',
  );

  /// This app's registered ThunderID client ID (public/native client, no
  /// secret — see doc/setup/thunderid-mobile-client.md).
  static const String thunderIdClientId = String.fromEnvironment(
    'THUNDERID_CLIENT_ID',
  );

  /// This app's ThunderID **Application ID** — not the Client ID; ThunderID's
  /// recovery gate only accepts the former. Optional: without it the
  /// password-reset entry points explain where else to reset instead
  /// (doc/setup/thunderid-mobile-client.md → Password recovery).
  static const String thunderIdApplicationId = String.fromEnvironment(
    'THUNDERID_APPLICATION_ID',
  );

  /// ThunderID's hosted password-recovery page for this app (enter email →
  /// single-use link → new password), or null when not configured. CoreGrid
  /// never sees the password.
  static Uri? get passwordRecoveryUrl {
    var issuer = thunderIdIssuer.trim();
    while (issuer.endsWith('/')) {
      issuer = issuer.substring(0, issuer.length - 1);
    }
    if (issuer.isEmpty || thunderIdApplicationId.isEmpty) return null;
    return Uri.parse('$issuer/gate/recovery')
        .replace(queryParameters: {'applicationId': thunderIdApplicationId});
  }

  /// Must match the custom scheme registered with ThunderID and the
  /// `appAuthRedirectScheme` manifest placeholder in
  /// android/app/build.gradle.kts.
  static const String redirectUrl = 'com.coregrid.mobile://auth-callback';

  /// Whether both the API and ThunderID are configured over `https://`.
  /// Release builds refuse to sign in otherwise (SRS §4.8) — debug builds
  /// skip the check so local dev setups keep working.
  static bool get usesHttps =>
      apiBaseUrl.trim().startsWith('https://') &&
      thunderIdIssuer.trim().startsWith('https://');

  static bool get isConfigured =>
      apiBaseUrl.isNotEmpty &&
      thunderIdIssuer.isNotEmpty &&
      thunderIdClientId.isNotEmpty;
}

