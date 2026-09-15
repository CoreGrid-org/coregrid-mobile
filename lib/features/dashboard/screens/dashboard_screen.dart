import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/auth/auth_controller.dart';
import '../../../shared/auth/auth_state.dart';
import '../../../shared/theme/app_theme.dart';
import 'officer_dashboard_screen.dart';
import 'staff_dashboard_screen.dart';

/// FR-083 — routes to the role-appropriate dashboard body. `features/
/// verification` now feeds its own section live (see
/// `OfficerDashboardBody`); `features/maintenance`/`features/transfers`
/// still don't exist, so those sections stay mock until those owners land
/// them. This lets Dev Sign In (§4.1) demonstrate the Officer/Staff split
/// described in the main SRS §2.3.1 in the meantime.
///
/// Each role gets a [RoleAccent] tint on the app bar and its primary action
/// — a lightweight visual cue for which dashboard is on screen, without
/// forking the whole `ColorScheme` per role.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sign-out (the app bar action below) only changes provider state —
    // go_router has no `refreshListenable` wired to it, so nothing else
    // would ever navigate away from `/home` afterwards. Mirrors
    // `SignInScreen`'s own `ref.listen`-driven navigation on the opposite
    // transition (signed-out → signed-in).
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthUnauthenticated) {
        context.go('/sign-in');
      }
    });

    final state = ref.watch(authControllerProvider);
    final role = state is AuthAuthenticated ? state.role : null;
    final displayName = state is AuthAuthenticated ? state.displayName : null;
    final accent = RoleAccent.forRole(role);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName ?? 'CoreGrid'),
        backgroundColor: colors.surface,
        actions: [
          if (role != null) _RoleBadge(role: role, accent: accent),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: accent),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MockBanner(),
          switch (role) {
            'InventoryOfficer' => const OfficerDashboardBody(),
            'Staff' => const StaffDashboardBody(),
            _ => const Text('Signed in — role unknown (backend unreachable).'),
          },
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: accent, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MockBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.construction_outlined,
            size: 18,
            color: colors.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Partial mock dashboard — Verification Tasks Due is live; '
              'features/maintenance and features/transfers aren\'t built yet '
              'so those sections are still sample data.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
