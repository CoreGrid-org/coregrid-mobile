import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/auth/auth_controller.dart';
import '../../../shared/auth/auth_state.dart';
import 'officer_dashboard_screen.dart';
import 'staff_dashboard_screen.dart';

/// FR-083 — routes to the role-appropriate mock dashboard body. Mock: no
/// `features/dashboard` provider or API call yet — TEAM-ALLOCATION.md scopes
/// the real, data-backed dashboard for after `verification`/`maintenance`/
/// `transfers` exist to summarise. This lets Dev Sign In (§4.1) demonstrate
/// the Officer/Staff split described in the main SRS §2.3.1 in the meantime.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final role = state is AuthAuthenticated ? state.role : null;
    final displayName = state is AuthAuthenticated ? state.displayName : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName ?? 'CoreGrid'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.construction_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mock dashboard — sample data, not live. features/verification, '
                    'features/maintenance and features/transfers aren\'t built yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
