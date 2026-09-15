import 'package:dio/dio.dart';

/// Typed error surfaced by every feature's API layer (`MOBILE-SPECIFICATION.md`
/// §3.4). Screens map this to a plain-language message and, where present,
/// per-field form errors (IF-03/IF-09) — they never show a raw `DioException`.
///
/// `shared/api/` is nominally the app-shell owner's (Student 4) cross-cutting
/// area per `TEAM-ALLOCATION.md`; this is a deliberately minimal client stood
/// up so `features/assets/` can talk to the API. Refresh-token retry (§3.4) is
/// left as a `TODO` for the shell owner rather than duplicated here.
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.fieldErrors = const {},
    this.isNetworkError = false,
  });

  /// HTTP status, or 0 when the request never reached the server.
  final int statusCode;

  /// Human-readable, safe to show to the user.
  final String message;

  /// `field name -> messages`, parsed from an ASP.NET `ValidationProblemDetails`
  /// `errors` object. Empty for non-validation failures.
  final Map<String, List<String>> fieldErrors;

  /// True when the failure is connectivity, not an HTTP response — lets a
  /// screen show the "offline" state (FR-024 A4) instead of a generic error.
  final bool isNetworkError;

  bool get isNotFound => statusCode == 404;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  /// Builds an [ApiException] from whatever dio threw.
  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(
          statusCode: 0,
          message:
              'Can\'t reach CoreGrid. Check your connection and try again.',
          isNetworkError: true,
        );
      case DioExceptionType.badResponse:
        final response = e.response;
        final status = response?.statusCode ?? 0;
        return ApiException(
          statusCode: status,
          message: _messageFor(status, response?.data),
          fieldErrors: _fieldErrorsFrom(response?.data),
        );
      case DioExceptionType.cancel:
        return ApiException(statusCode: 0, message: 'Request cancelled.');
      case DioExceptionType.badCertificate:
        return ApiException(
          statusCode: 0,
          message: 'The server\'s security certificate could not be verified.',
          isNetworkError: true,
        );
      case DioExceptionType.unknown:
        return ApiException(
          statusCode: 0,
          message: 'Something went wrong talking to CoreGrid.',
          isNetworkError: true,
        );
    }
  }

  static String _messageFor(int status, Object? data) {
    // The backend's domain errors come back as `{ "message": "..." }`
    // (AssetsController); model-validation failures as ValidationProblemDetails
    // with a `title`. Prefer whichever is present.
    if (data is Map) {
      final message = data['message'] ?? data['detail'] ?? data['title'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
    return switch (status) {
      400 => 'That request wasn\'t valid.',
      401 => 'Your session has expired. Please sign in again.',
      403 => 'You don\'t have permission to do that.',
      404 => 'Asset not found.',
      409 => 'That change conflicts with the current state of the asset.',
      >= 500 => 'CoreGrid had a problem handling that. Try again shortly.',
      _ => 'Request failed ($status).',
    };
  }

  static Map<String, List<String>> _fieldErrorsFrom(Object? data) {
    if (data is! Map) return const {};
    final errors = data['errors'];
    if (errors is! Map) return const {};
    return errors.map(
      (key, value) => MapEntry(
        key.toString(),
        (value is List ? value : [value]).map((v) => v.toString()).toList(),
      ),
    );
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
