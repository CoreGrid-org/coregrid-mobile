import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/auth/auth_controller.dart';
import '../../../shared/auth/auth_state.dart';
import '../../../shared/widgets/ui.dart';
import '../../maintenance/maintenance_providers.dart';
import '../../verification/verification_providers.dart';
import '../../workflows/workflows_providers.dart';
import '../widgets/greeting_header.dart';
import 'officer_dashboard_screen.dart';
import 'staff_dashboard_screen.dart';

/// The Home tab (FR-081–FR-083): greeting, "Find an asset", and a
/// role-specific summary of what needs the user's attention.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final role = state is AuthAuthenticated ? state.role : null;
    final displayName = state is AuthAuthenticated ? state.displayName : null;
    final profileError = state is AuthAuthenticated ? state.profileError : null;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(myFaultReportsProvider)
              ..invalidate(myVerificationTasksProvider)
              ..invalidate(agentWorkflowsProvider);
            await Future.wait([
              ref
                  .read(myFaultReportsProvider.future)
                  .then((_) {}, onError: (_) {}),
              if (role == 'InventoryOfficer')
                ref
                    .read(myVerificationTasksProvider.future)
                    .then((_) {}, onError: (_) {}),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.lg,
              AppSpacing.page,
              AppSpacing.xxl,
            ),
            children: [
              GreetingHeader(displayName: displayName, role: role),
              const SizedBox(height: AppSpacing.xl),
              switch (role) {
                'InventoryOfficer' => const OfficerDashboardBody(),
                'Staff' => const StaffDashboardBody(),
                _ => Notice(
                  tone: StatusTone.danger,
                  title:
                      'Signed in, but your CoreGrid role couldn\'t be loaded.',
                  message:
                      '${profileError ?? 'Unknown error.'}\n'
                      'Sign out and back in to retry.',
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}
