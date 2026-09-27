import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/auth/auth_controller.dart';
import '../../../shared/auth/auth_state.dart';
import '../../../shared/auth/me_provider.dart';
import '../../../shared/widgets/ui.dart';
import '../../maintenance/maintenance_providers.dart';
import '../../verification/verification_providers.dart';
import '../../workflows/workflows_providers.dart';
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
              _Greeting(
                displayName: displayName,
                role: role,
                department: ref
                    .watch(myWorkplaceProvider)
                    .asData
                    ?.value
                    ?.departmentName,
              ),
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

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.displayName,
    required this.role,
    required this.department,
  });

  final String? displayName;
  final String? role;
  final String? department;

  String get _salutation {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = displayName ?? 'there';
    final meta = [
      if (role != null) roleLabel(role!),
      ?department,
      DateFormat('EEE d MMM').format(DateTime.now()),
    ].join(' · ');

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_salutation, $name', style: context.text.headlineSmall),
              const SizedBox(height: 2),
              Text(meta, style: context.mutedBody),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Tooltip(
          message: 'Account',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.go('/account'),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: context.colors.primary,
              child: Text(
                name == 'there' ? '?' : name.characters.first.toUpperCase(),
                style: context.text.titleMedium?.copyWith(
                  color: context.colors.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
