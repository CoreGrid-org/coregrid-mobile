import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_config.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';

/// The one shared `dio` instance (`MOBILE-SPECIFICATION.md` §3.4). Every
/// feature's `*_api.dart` resolves this rather than constructing its own
/// client, so auth-header attachment and base-URL config live in exactly one
/// place.
///
/// Auth interceptor responsibilities implemented here:
///  - attach the in-memory access token as `Authorization: Bearer <token>`.
///  - never log request/response bodies (SEC-ID-05) — dio logs nothing by
///    default and no `LogInterceptor` is added.
///
/// NOT yet implemented (belongs to the shell owner's `shared/auth/` work per
/// `TEAM-ALLOCATION.md`): the single silent refresh-and-retry on 401 described
/// in §3.4. Until `AuthController` exposes a refresh, a 401 surfaces as an
/// [ApiException] with `isUnauthorized == true` and the calling screen shows
/// the "session expired" error state.
/// Normalises whatever came in via `--dart-define=API_BASE_URL`. The convention
/// is a bare origin (`http://localhost:5083`) — every call in the app prefixes
/// `/api/...` itself. A trailing `/` or an accidentally-appended `/api` is a
/// common run-command slip (it produces a silent `/api/api/...` → 404), so
/// strip both here rather than let every request 404.
String _normalizeBaseUrl(String raw) {
  var url = raw.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  if (url.endsWith('/api')) {
    url = url.substring(0, url.length - '/api'.length);
  }
  return url;
}

final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _normalizeBaseUrl(AuthConfig.apiBaseUrl),
      connectTimeout: const Duration(seconds: 5),
      // IF-06/FR-024 hold the scan→record path to 3s; give the request itself
      // a little more headroom before we call it a timeout.
      receiveTimeout: const Duration(seconds: 8),
      contentType: Headers.jsonContentType,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final auth = ref.read(authControllerProvider);
        if (auth is AuthAuthenticated) {
          options.headers['Authorization'] = 'Bearer ${auth.accessToken}';
        }
        handler.next(options);
      },
    ),
  );

  return dio;
});
