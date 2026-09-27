/// Environment configuration for auth and the API client, read via
/// `--dart-define` (or `--dart-define-from-file`) — never hardcoded, never
/// committed (`doc/MOBILE-SPECIFICATION.md` §5.1).
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
  /// secret — see doc/setup/ThunderID-mobile-client.md).
  static const String thunderIdClientId = String.fromEnvironment(
    'THUNDERID_CLIENT_ID',
  );

  /// Must match the custom scheme registered with ThunderID and the
  /// `appAuthRedirectScheme` manifest placeholder in
  /// android/app/build.gradle.kts.
  static const String redirectUrl = 'com.coregrid.mobile://auth-callback';

  static bool get isConfigured =>
      apiBaseUrl.isNotEmpty &&
      thunderIdIssuer.isNotEmpty &&
      thunderIdClientId.isNotEmpty;
}
