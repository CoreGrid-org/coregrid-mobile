import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/auth/auth_controller.dart';
import '../../../shared/auth/me_provider.dart';
import '../../../shared/widgets/ui.dart';
import '../../notifications/widgets/notification_bell.dart';

/// The Home tab's hero: avatar, time-of-day greeting, name and
/// organisation, then role / department / date as chips. Profile details
/// fill in from `GET /api/me` as they load; until then it falls back to
/// what sign-in already knows.
class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({
    super.key,
    required this.displayName,
    required this.role,
  });

  /// From sign-in (`given_name`) — shown until the full profile loads.
  final String? displayName;
  final String? role;

  static String _salutation(DateTime now) => switch (now.hour) {
    < 12 => 'Good morning',
    < 17 => 'Good afternoon',
    _ => 'Good evening',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).asData?.value;
    final department = ref.watch(myWorkplaceProvider).asData?.value;
    final now = DateTime.now();

    final name = me?.fullName.isNotEmpty == true
        ? me!.fullName
        : (displayName ?? 'there');
    final initials =
        me?.initials ??
        (name == 'there' ? '?' : name.characters.first.toUpperCase());
    final org = me?.organizationName;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_salutation(now), style: context.mutedBody),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    if (org != null && org.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        org,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.mutedSmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const NotificationBell(),
              const SizedBox(width: AppSpacing.xs),
              Tooltip(
                message: 'Account',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.go('/account'),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: CoreGridBrand.orangeDeep,
                    child: Text(
                      initials,
                      style: context.text.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.xs + 2,
            runSpacing: AppSpacing.xs + 2,
            children: [
              if (role != null)
                _InfoChip(icon: Icons.badge_outlined, label: roleLabel(role!)),
              if (department != null)
                _InfoChip(
                  icon: Icons.apartment_rounded,
                  label: department.departmentName,
                ),
              _InfoChip(
                icon: Icons.calendar_today_rounded,
                label: DateFormat('EEE, d MMM').format(now),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Simple neutral pill badge for role / department / date.
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: Clay.surface(context, radius: AppRadius.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.colors.primary),
          const SizedBox(width: AppSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
