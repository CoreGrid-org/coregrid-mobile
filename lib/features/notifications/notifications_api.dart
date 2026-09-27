import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/api_client.dart';
import '../../shared/api/api_exception.dart';
import 'models/app_notification.dart';

/// Every `/api/notifications` call (FR-080). All roles may use it; each call
/// only ever touches the caller's own inbox (the API scopes by token).
class NotificationsApi {
  NotificationsApi(this._dio);

  final Dio _dio;

  static const pageSize = 20;

  /// `GET /api/notifications` — newest first.
  Future<NotificationPage> list({int page = 1, bool onlyUnread = false}) =>
      _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/notifications',
          queryParameters: {
            'page': page,
            'pageSize': pageSize,
            if (onlyUnread) 'onlyUnread': true,
          },
        );
        return NotificationPage.fromJson(response.data ?? const {});
      });

  /// `GET /api/notifications/unread-count`.
  Future<int> unreadCount() => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/notifications/unread-count',
    );
    return (response.data?['count'] as num?)?.toInt() ?? 0;
  });

  /// `PATCH /api/notifications/{id}/read`.
  Future<void> markRead(String id) =>
      _guard(() => _dio.patch<void>('/api/notifications/$id/read'));

  /// `PATCH /api/notifications/read-all`.
  Future<void> markAllRead() =>
      _guard(() => _dio.patch<void>('/api/notifications/read-all'));

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final notificationsApiProvider = Provider<NotificationsApi>((ref) {
  return NotificationsApi(ref.watch(apiClientProvider));
});
