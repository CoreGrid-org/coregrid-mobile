import 'package:coregrid_mobile/features/notifications/models/app_notification.dart';
import 'package:coregrid_mobile/features/notifications/notifications_api.dart';
import 'package:coregrid_mobile/features/notifications/screens/notifications_screen.dart';
import 'package:coregrid_mobile/features/notifications/widgets/notification_bell.dart';
import 'package:coregrid_mobile/shared/widgets/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

AppNotification _n(String id, {bool read = false}) => AppNotification.fromJson({
  'id': id,
  'type': 'MAINTENANCE_ASSIGNED',
  'title': 'Maintenance assigned to you',
  'message': 'AST-00$id needs a repair',
  'related_entity_type': 'MaintenanceRecord',
  'related_entity_id': 'm$id',
  'is_read': read,
  'created_at': DateTime.now().toUtc().toIso8601String(),
});

class _Api extends Fake implements NotificationsApi {
  _Api(this.items);

  List<AppNotification> items;
  final marked = <String>[];
  var allMarked = false;

  @override
  Future<NotificationPage> list({
    int page = 1,
    bool onlyUnread = false,
  }) async => NotificationPage(
    items: [
      for (final n in items)
        if (!onlyUnread || !n.isRead) n,
    ],
    page: 1,
    totalPages: 1,
  );

  @override
  Future<int> unreadCount() async => items.where((n) => !n.isRead).length;

  @override
  Future<void> markRead(String id) async => marked.add(id);

  @override
  Future<void> markAllRead() async {
    allMarked = true;
    items = [for (final n in items) n.copyWith(isRead: true)];
  }
}

Widget _app(_Api api, Widget home) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/maintenance/:id',
        builder: (_, s) => Text('record ${s.pathParameters['id']}'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [notificationsApiProvider.overrideWithValue(api)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  test('related records map to in-app routes', () {
    expect(_n('1').route, '/maintenance/m1');
    final unknown = AppNotification.fromJson({
      'id': 'x',
      'related_entity_type': 'Disposal',
      'related_entity_id': 'd1',
    });
    expect(unknown.route, isNull);
  });

  test('describeAgo', () {
    final now = DateTime(2026, 9, 27, 12);
    expect(describeAgo(now, now: now), 'Just now');
    expect(
      describeAgo(now.subtract(const Duration(minutes: 5)), now: now),
      '5 min ago',
    );
    expect(
      describeAgo(now.subtract(const Duration(hours: 3)), now: now),
      '3 h ago',
    );
    expect(describeAgo(DateTime(2026, 9, 26, 9), now: now), 'Yesterday');
  });

  testWidgets('bell shows the unread count and opens the inbox', (
    tester,
  ) async {
    final api = _Api([_n('1'), _n('2'), _n('3', read: true)]);
    await tester.pumpWidget(
      _app(api, const Scaffold(body: Center(child: NotificationBell()))),
    );
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byType(NotificationBell));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Maintenance assigned to you'), findsNWidgets(3));
  });

  testWidgets('tapping marks read and opens the related record', (
    tester,
  ) async {
    final api = _Api([_n('1')]);
    await tester.pumpWidget(_app(api, const NotificationsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AST-001 needs a repair'));
    await tester.pumpAndSettle();

    expect(api.marked, ['1']);
    expect(find.text('record m1'), findsOneWidget);
  });

  testWidgets('mark all read, and the unread filter empties', (tester) async {
    final api = _Api([_n('1'), _n('2')]);
    await tester.pumpWidget(_app(api, const NotificationsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    expect(api.allMarked, isTrue);

    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();
    expect(find.text('You\'re all caught up'), findsOneWidget);
  });
}
