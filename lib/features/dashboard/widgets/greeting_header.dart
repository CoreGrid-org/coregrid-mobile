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

    const onBrand = Colors.white;
    final onBrandMuted = onBrand.withValues(alpha: 0.78);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card + 4),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CoreGridBrand.greenDeep, Color(0xFF0B4A3A)],
        ),
        boxShadow: [
          BoxShadow(
            color: CoreGridBrand.greenDeep.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _salutation(now),
                      style: context.text.bodyMedium?.copyWith(
                        color: onBrandMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.headlineSmall?.copyWith(
                        color: onBrand,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (org != null && org.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        org,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: onBrandMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const NotificationBell(color: onBrand),
              const SizedBox(width: AppSpacing.xs),
              Tooltip(
                message: 'Account',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.go('/account'),
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: onBrand.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: onBrand,
                      child: Text(
                        initials,
                        style: context.text.titleMedium?.copyWith(
                          color: CoreGridBrand.greenDeep,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
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

/// Translucent icon + label pill on the brand background.
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md - 2,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: AppSpacing.xs + 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
