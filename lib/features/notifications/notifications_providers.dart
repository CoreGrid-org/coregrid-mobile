import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_notification.dart';
import 'notifications_api.dart';

/// The badge number on the Home bell.
final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(notificationsApiProvider).unreadCount();
});

/// One page of the inbox — `(onlyUnread, page)`. The screen watches pages
/// 1..n and concatenates them ("Load more").
final notificationPageProvider = FutureProvider.autoDispose
    .family<NotificationPage, (bool, int)>((ref, key) {
      final (onlyUnread, page) = key;
      return ref
          .watch(notificationsApiProvider)
          .list(page: page, onlyUnread: onlyUnread);
    });

/// Marking notifications read. Failures are swallowed on purpose: read
/// state is a convenience, and the next refresh shows the server's truth.
class NotificationReadController extends Notifier<Set<String>> {
  /// Ids marked read this session — lets the list update immediately
  /// without refetching every page.
  @override
  Set<String> build() => const {};

  Future<void> markRead(String id) async {
    state = {...state, id};
    try {
      await ref.read(notificationsApiProvider).markRead(id);
    } catch (_) {
      // Leave it; the list will re-sync from the server.
    }
    ref.invalidate(unreadNotificationCountProvider);
  }

  Future<bool> markAllRead() async {
    try {
      await ref.read(notificationsApiProvider).markAllRead();
    } catch (_) {
      return false;
    }
    ref
      ..invalidate(notificationPageProvider)
      ..invalidate(unreadNotificationCountProvider);
    return true;
  }
}

final notificationReadControllerProvider =
    NotifierProvider.autoDispose<NotificationReadController, Set<String>>(
      NotificationReadController.new,
    );
