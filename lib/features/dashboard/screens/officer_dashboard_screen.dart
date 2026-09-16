import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../../verification/verification_providers.dart';
import '../widgets/dashboard_section.dart';

/// Inventory Officer's dashboard body. SRS §2.3.1's Mobile-users table
/// lists this role's Flutter scope as: scan/lookup, verification tasks and
/// completion (FR-031/058/059), discrepancy raising (FR-061), fault
/// reporting (FR-033, shared with Staff, not Staff-only), condition
/// recording (FR-029), maintenance progress update (FR-037), transfer
/// request and receipt confirmation (FR-043/046), and agent workflow
/// initiate/outcome (FR-067/076), summarised per FR-083. Asset
/// registration (FR-021-023) is not in this list anywhere: per the SRS's
/// own Web-users table it's React-only, not just Officer-only, so this
/// dashboard has no "add asset" action for any role. Maintenance/transfer
/// rows are still mock (those features aren't built); the verification
/// section below is live (`features/verification/`, this owner's own
/// feature).
class OfficerDashboardBody extends ConsumerWidget {
  const OfficerDashboardBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const accent = RoleAccent.officer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        QuickActionsGrid(
          actions: [
            QuickAction(
              primary: true,
              accent: accent,
              icon: Icons.qr_code_scanner,
              label: 'Scan Asset',
              onTap: () => notBuiltYet(context, 'features/scan'),
            ),
            // FR-025: manual code entry, always available (routes to
            // features/assets/ Asset Detail).
            QuickAction(
              accent: accent,
              icon: Icons.keyboard_outlined,
              label: 'Enter Code',
              onTap: () => context.push('/assets'),
            ),
            QuickAction(
              accent: accent,
              icon: Icons.manage_search,
              label: 'Search Assets',
              onTap: () => context.push('/assets/search'),
            ),
            QuickAction(
              accent: accent,
              icon: Icons.fact_check_outlined,
              label: 'Verification',
              onTap: () => context.push('/verification'),
            ),
            QuickAction(
              accent: accent,
              icon: Icons.smart_toy_outlined,
              label: 'Workflows',
              onTap: () => context.push('/workflows'),
            ),
            QuickAction(
              accent: accent,
              icon: Icons.local_shipping_outlined,
              label: 'Transfer',
              onTap: () => notBuiltYet(context, 'features/transfers'),
            ),
            // FR-033: fault reporting is Officer and Staff (SRS §2.3.1
            // Mobile-users table), not Staff-only.
            QuickAction(
              accent: accent,
              icon: Icons.report_problem_outlined,
              label: 'Report Fault',
              onTap: () => notBuiltYet(context, 'features/maintenance'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _VerificationTasksDueSection(accent: accent),
        DashboardSection(
          title: 'Maintenance Assigned to Me',
          icon: Icons.build_outlined,
          accent: accent,
          rows: const [
            DashboardRow(
              label: 'AST-00147: Air Compressor',
              detail: 'Corrective, priority high',
              status: 'In Progress',
            ),
          ],
        ),
        DashboardSection(
          title: 'Transfers Awaiting My Confirmation',
          icon: Icons.move_to_inbox_outlined,
          accent: accent,
          rows: const [
            DashboardRow(
              label: 'AST-00305: Laptop, from Finance Dept.',
              detail: 'Requested 1 day ago',
              status: 'In Transit',
            ),
          ],
        ),
      ],
    );
  }
}

/// The dashboard's one live section (FR-058 data, summarised per FR-083);
/// everything else on this screen is still mock pending
/// `features/maintenance`/`features/transfers`. Loading/error states
/// collapse quietly into the section itself rather than blocking the rest
/// of the (still-mock) dashboard, matching §4.2's "per section,
/// independently retryable" rule.
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
              label: '${task.assetCode}: ${task.assetName}',
              detail: task.isOverdue
                  ? 'Overdue since ${task.dueDate.year}-${task.dueDate.month.toString().padLeft(2, '0')}-${task.dueDate.day.toString().padLeft(2, '0')}'
                  : 'Due ${task.dueDate.year}-${task.dueDate.month.toString().padLeft(2, '0')}-${task.dueDate.day.toString().padLeft(2, '0')}',
              status: task.status.apiValue,
              onTap: () => context.push('/verification/${task.id}'),
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
