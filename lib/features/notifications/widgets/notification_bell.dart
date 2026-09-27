import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../notifications_providers.dart';

/// Bell with the unread count (FR-080). Re-checks every minute while its
/// tab is visible and the app is in the foreground, and on resume.
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key, this.color});

  final Color? color;

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell>
    with WidgetsBindingObserver {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(const Duration(minutes: 1), (_) {
      final visible = mounted && TickerMode.valuesOf(context).enabled;
      final foreground =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (visible && foreground) {
        ref.invalidate(unreadNotificationCountProvider);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(unreadNotificationCountProvider);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(unreadNotificationCountProvider).asData?.value ?? 0;
    return IconButton(
      tooltip: count == 0 ? 'Notifications' : 'Notifications, $count unread',
      color: widget.color,
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: Icon(
          count > 0
              ? Icons.notifications_active_outlined
              : Icons.notifications_none_rounded,
        ),
      ),
    );
  }
}
