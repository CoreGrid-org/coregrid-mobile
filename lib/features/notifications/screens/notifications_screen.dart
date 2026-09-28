import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/ui.dart';
import '../models/app_notification.dart';
import '../notifications_providers.dart';

/// FR-080: the user's recent notifications with unread state — All / Unread,
/// "Mark all read", and "Load more". Tapping one marks it read and opens
/// the record it's about. Route: `/notifications` (every role).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _onlyUnread = false;
  int _pages = 1;

  Future<void> _refresh() async {
    ref
      ..invalidate(notificationPageProvider)
      ..invalidate(unreadNotificationCountProvider);
    setState(() => _pages = 1);
    await ref.read(notificationPageProvider((_onlyUnread, 1)).future);
  }

  Future<void> _markAllRead() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(notificationReadControllerProvider.notifier)
        .markAllRead();
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Couldn\'t mark all as read. Try again.')),
      );
    }
    if (mounted) setState(() => _pages = 1);
  }

  Future<void> _open(AppNotification n, bool isRead) async {
    if (!isRead) {
      // Don't wait for the server — the tap should feel instant.
      ref.read(notificationReadControllerProvider.notifier).markRead(n.id);
    }
    final route = n.route;
    if (route != null) await context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final readIds = ref.watch(notificationReadControllerProvider);
    final unread = ref.watch(unreadNotificationCountProvider).asData?.value;

    final pages = [
      for (var p = 1; p <= _pages; p++)
        ref.watch(notificationPageProvider((_onlyUnread, p))),
    ];
    final first = pages.first;
    final last = pages.last;
    final items = [
      for (final p in pages.takeWhile((p) => p.hasValue)) ...p.value!.items,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: (unread ?? 0) > 0 ? _markAllRead : null,
            child: const Text('Mark all read'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: [
                  const ButtonSegment(value: false, label: Text('All')),
                  ButtonSegment(
                    value: true,
                    label: Text(
                      unread == null || unread == 0
                          ? 'Unread'
                          : 'Unread · $unread',
                    ),
                  ),
                ],
                selected: {_onlyUnread},
                onSelectionChanged: (v) => setState(() {
                  _onlyUnread = v.first;
                  _pages = 1;
                }),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: switch (first) {
          AsyncError(:final error) when !first.hasValue => ErrorView(
            error: error,
            title: 'Couldn\'t load notifications',
            onRetry: () => ref.invalidate(notificationPageProvider),
          ),
          _ when !first.hasValue => const LoadingView(),
          _ when items.isEmpty => MessageView(
            icon: Icons.notifications_none_rounded,
            title: _onlyUnread ? 'You\'re all caught up' : 'No notifications',
            message:
                'You\'ll hear here when maintenance is assigned to you or '
                'something you reported changes.',
          ),
          _ => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.pageInsets,
            children: [
              ListCard(
                children: [
                  for (final n in items)
                    _NotificationTile(
                      notification: n,
                      isRead: n.isRead || readIds.contains(n.id),
                      onTap: (isRead) => _open(n, isRead),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              switch (last) {
                AsyncError(:final error) => Notice(
                  tone: StatusTone.danger,
                  message: errorMessageFor(error),
                ),
                _ when !last.hasValue => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: CircularProgressIndicator(),
                  ),
                ),
                _ when last.value!.hasMore => OutlinedButton(
                  onPressed: () => setState(() => _pages++),
                  child: const Text('Load more'),
                ),
                _ => const SizedBox(),
              },
            ],
          ),
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.isRead,
    required this.onTap,
  });

  final AppNotification notification;
  final bool isRead;
  final ValueChanged<bool> onTap;

  static IconData _icon(String type) {
    final t = type.toUpperCase();
    if (t.contains('ASSIGNED')) return Icons.engineering_outlined;
    if (t.contains('CANCEL')) return Icons.cancel_outlined;
    if (t.contains('COMPLETED')) return Icons.task_alt_rounded;
    if (t.startsWith('MAINTENANCE')) return Icons.build_circle_outlined;
    if (t.startsWith('TRANSFER')) return Icons.local_shipping_outlined;
    if (t.contains('WORKFLOW') || t.contains('EVALUATION')) {
      return Icons.auto_awesome_outlined;
    }
    return Icons.notifications_none_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return Semantics(
      label: isRead ? null : 'Unread',
      child: InkWell(
        onTap: () => onTap(isRead),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md + 2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(
                _icon(n.type),
                tone: isRead ? StatusTone.neutral : StatusTone.info,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: context.text.bodyLarge?.copyWith(
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(n.message, style: context.mutedBody),
                    const SizedBox(height: AppSpacing.xs),
                    Text(describeAgo(n.createdAt), style: context.mutedSmall),
                  ],
                ),
              ),
              if (!isRead) ...[
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: CircleAvatar(
                    radius: 5,
                    backgroundColor: context.colors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
