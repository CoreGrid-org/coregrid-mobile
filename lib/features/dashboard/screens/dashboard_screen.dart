import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/auth/auth_controller.dart';
import '../../../shared/auth/auth_state.dart';
import '../../../shared/theme/app_theme.dart';
import '../../maintenance/maintenance_providers.dart';
import '../../verification/verification_providers.dart';
import 'officer_dashboard_screen.dart';
import 'staff_dashboard_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthUnauthenticated) {
        context.go('/sign-in');
      }
    });

    final state = ref.watch(authControllerProvider);
    final role = state is AuthAuthenticated ? state.role : null;
    final displayName = state is AuthAuthenticated ? state.displayName : null;
    final accent = RoleAccent.forRole(role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          if (role != null) _RoleBadge(role: role, accent: accent),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Sign Out',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myFaultReportsProvider);
          ref.invalidate(myVerificationTasksProvider);
          try {
            await ref.read(myFaultReportsProvider.future);
          } catch (_) {}
          try {
            await ref.read(myVerificationTasksProvider.future);
          } catch (_) {}
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GreetingHeader(displayName: displayName, role: role),
              const SizedBox(height: 24),
              switch (role) {
                'InventoryOfficer' => const OfficerDashboardBody(),
                'Staff' => const StaffDashboardBody(),
                _ => const Text(
                  'Signed in, role unknown (backend unreachable).',
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.displayName, required this.role});

  final String? displayName;
  final String? role;

  String get _timeOfDayGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name =
        displayName ??
        (role == 'InventoryOfficer' ? 'Officer' : role ?? 'there');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _timeOfDayGreeting,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, required this.accent});

  final String role;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final label = role == 'InventoryOfficer' ? 'Officer' : role;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: accent, fontWeight: FontWeight.w700),
      ),
    );
  }
}

