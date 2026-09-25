import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../widgets/dashboard_section.dart';
import '../widgets/my_fault_reports_section.dart';

/// Staff dashboard — fault reports and quick actions.
class StaffDashboardBody extends StatelessWidget {
  const StaffDashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
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
              onTap: () => context.push('/scan'),
            ),
            // Manual code entry
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
            // Report fault
            QuickAction(
              accent: accent,
              icon: Icons.report_problem_outlined,
              label: 'Report Fault',
              onTap: () => context.push('/maintenance/report'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const MyFaultReportsSection(accent: accent),
      ],
    );
  }
}
