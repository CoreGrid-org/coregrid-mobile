import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/ui.dart';
import '../../maintenance/maintenance_providers.dart';
import '../../maintenance/widgets/fault_tile.dart';
import '../../transfers/transfers_providers.dart';
import '../../transfers/widgets/transfer_summary_card.dart';
import '../../verification/models/verification_task.dart';
import '../../verification/screens/verification_task_list_screen.dart';
import '../../verification/verification_providers.dart';
import '../../workflows/screens/workflow_list_screen.dart';
import '../../workflows/workflows_providers.dart';
import '../widgets/dashboard_section.dart';
import '../widgets/find_asset_card.dart';

/// Inventory Officer home: find an asset, today's numbers, shortcuts, and
/// previews of verification tasks, maintenance assigned to them, transfers
/// to receive, evaluations and fault reports.
class OfficerDashboardBody extends ConsumerWidget {
  const OfficerDashboardBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(myVerificationTasksProvider);
    final faults = ref.watch(myFaultReportsProvider);
    final workflows = ref.watch(agentWorkflowsProvider);
    final assigned = ref.watch(myAssignedMaintenanceProvider);
    final incoming = ref.watch(pendingConfirmationProvider);

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
        const SectionHeader('Your workload'),
        StatRow(
          cards: [
            StatCard(
              value: overdue,
              label: 'Overdue tasks',
              tone: StatusTone.danger,
              onTap: () => context.go('/verification'),
            ),
            StatCard(
              value: pendingList?.length,
              label: 'Tasks to verify',
              tone: StatusTone.warning,
              onTap: () => context.go('/verification'),
            ),
            StatCard(
              value: openFaults,
              label: 'Open fault reports',
              tone: StatusTone.info,
              onTap: () => context.go('/faults'),
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
        DashboardPreview(
          title: 'Maintenance assigned to me',
          data: assigned,
          emptyLabel: 'No maintenance work assigned to you.',
          onSeeAll: () => context.go('/faults?view=assigned'),
          itemBuilder: FaultTile.new,
        ),
        DashboardPreview(
          title: 'Transfers to receive',
          data: incoming,
          emptyLabel: 'No approved transfers heading to your department.',
          onSeeAll: () => context.push('/transfers'),
          itemBuilder: (transfer) => TransferSummaryCard(transfer: transfer),
        ),
        DashboardPreview(
          title: 'Recent evaluations',
          data: workflows,
          maxItems: 2,
          emptyLabel: 'No agent evaluations yet.',
          onSeeAll: () => context.go('/workflows'),
          itemBuilder: WorkflowTile.new,
        ),
        DashboardPreview(
          title: 'My fault reports',
          data: faults,
          emptyLabel: 'You haven\'t reported any faults.',
          onSeeAll: () => context.go('/faults'),
          itemBuilder: FaultTile.new,
        ),
      ],
    );
  }
}
