import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../../transfers/transfers_providers.dart';
import '../../../shared/widgets/ui.dart';
import '../../maintenance/maintenance_providers.dart';
import '../../maintenance/widgets/fault_tile.dart';
import '../../verification/models/verification_task.dart';
import '../../verification/screens/verification_task_list_screen.dart';
import '../../verification/verification_providers.dart';
import '../../verification/verify_flow.dart';
import '../../workflows/screens/workflow_list_screen.dart';
import '../../workflows/workflows_providers.dart';
import '../widgets/dashboard_section.dart';
import '../widgets/find_asset_card.dart';

/// Inventory Officer home: find an asset, today's numbers, shortcuts, and
/// previews of verification tasks, evaluations and fault reports.
class OfficerDashboardBody extends ConsumerWidget {
  const OfficerDashboardBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(myVerificationTasksProvider);
    final faults = ref.watch(myFaultReportsProvider);
    final workflows = ref.watch(agentWorkflowsProvider);

    final pending = tasks.whenData(
      (list) =>
          list.where((t) => t.isPending).toList()
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate)),
    );
    final pendingList = pending.asData?.value;
    final overdue = pendingList?.where((t) => t.isOverdue).length;
    final openFaults = faults.asData?.value
        .where((r) => r.isOpen || r.isInProgress)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FindAssetCard(),
        const SectionHeader('At a glance'),
        StatRow(
          cards: [
            StatCard(
              value: overdue,
              label: 'Overdue\ntasks',
              tone: StatusTone.danger,
              onTap: () => context.go('/verification'),
            ),
            StatCard(
              value: pendingList?.length,
              label: 'Tasks to\nverify',
              tone: StatusTone.warning,
              onTap: () => context.go('/verification'),
            ),
            StatCard(
              value: openFaults,
              label: 'Open fault\nreports',
              tone: StatusTone.info,
              onTap: () => context.go('/faults'),
            ),
          ],
        ),
        const SectionHeader('Quick actions'),
        QuickActionsGrid(
          actions: [
            QuickAction(
              icon: Icons.build_circle_outlined,
              label: 'Report a fault',
              caption: 'Photo + description',
              onTap: () => context.push('/maintenance/report'),
            ),
            QuickAction(
              icon: Icons.auto_awesome_outlined,
              label: 'Request evaluation',
              caption: 'Ask the agent',
              onTap: () => context.push('/workflows/new'),
            ),
            QuickAction(
              accent: accent,
              icon: Icons.local_shipping_outlined,
              label: 'Transfer',
              onTap: () => context.push('/transfers'),
              icon: Icons.flag_outlined,
              label: 'Campaigns',
              caption: 'Progress & scope',
              onTap: () => context.go('/verification?view=campaigns'),
            ),
            QuickAction(
              icon: Icons.qr_code_scanner,
              label: 'Scan to verify',
              caption: 'Campaign task check',
              onTap: () => scanToVerify(context, ref),
            ),
          ],
        ),
        DashboardPreview<VerificationTask>(
          title: 'Verification due',
          data: pending,
          emptyLabel: 'No verification tasks assigned to you.',
          onSeeAll: () => context.go('/verification'),
          itemBuilder: (t) => TaskTile(task: t),
        ),
        _TransfersAwaitingConfirmationSection(accent: accent),
      ],
    );
  }
}

/// Verification tasks due section.
class _VerificationTasksDueSection extends ConsumerWidget {
  const _VerificationTasksDueSection({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(myVerificationTasksProvider);

    return switch (tasks) {
      AsyncData(:final value) => DashboardSection(
        title: 'Verification Tasks Due',
        icon: Icons.fact_check_outlined,
        accent: accent,
        emptyLabel: 'No verification tasks assigned to you',
        rows: [
          for (final task in value.where((t) => t.isPending).take(3))
            DashboardRow(
              label: ': ',
              detail: task.isOverdue
                  ? 'Overdue since --'
                  : 'Due --',
              status: task.status.apiValue,
              onTap: () => context.push('/verification/'),
            ),
        ],
      ),
      AsyncError() => DashboardSection(
        title: 'Verification Tasks Due',
        icon: Icons.fact_check_outlined,
        accent: accent,
        emptyLabel: 'Could not load verification tasks',
        rows: const [],
      ),
      _ => DashboardSection(
        title: 'Verification Tasks Due',
        icon: Icons.fact_check_outlined,
        accent: accent,
        emptyLabel: 'Loading...',
        rows: const [],
      ),
    };
  }
}

/// Transfers awaiting confirmation section (FR-046).
class _TransfersAwaitingConfirmationSection extends ConsumerWidget {
  const _TransfersAwaitingConfirmationSection({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(pendingConfirmationProvider);

    return switch (transfers) {
      AsyncData(:final value) => DashboardSection(
        title: 'Transfers Awaiting My Confirmation',
        icon: Icons.move_to_inbox_outlined,
        accent: accent,
        emptyLabel: 'No transfers awaiting confirmation',
        rows: [
          for (final t in value.take(3))
            DashboardRow(
              label: ': ',
              detail: t.fromDepartmentName != null
                  ? 'From '
                  : 'Transfer approved',
              status: t.status.label,
              onTap: () => context.push('/transfers/'),
            ),
        ],
      ),
      AsyncError() => DashboardSection(
        title: 'Transfers Awaiting My Confirmation',
        icon: Icons.move_to_inbox_outlined,
        accent: accent,
        emptyLabel: 'Could not load transfers',
        rows: const [],
      ),
      _ => DashboardSection(
        title: 'Transfers Awaiting My Confirmation',
        icon: Icons.move_to_inbox_outlined,
        accent: accent,
        emptyLabel: 'Loading...',
        rows: const [],
      ),
    };
  }
}
