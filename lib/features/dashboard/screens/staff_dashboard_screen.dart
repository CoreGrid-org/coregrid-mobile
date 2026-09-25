import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../widgets/dashboard_section.dart';

/// Staff's dashboard body. SRS §2.3.1: what they've reported and its
/// status (FR-033, FR-080, summarised per FR-083). Deliberately narrower
/// than the Officer's; Staff has no verification, maintenance-management or
/// transfer capability. Mock data, see [DashboardScreen]'s banner.
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
              icon: Icons.report_problem_outlined,
              label: 'Report Fault',
              onTap: () => notBuiltYet(context, 'features/maintenance'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        DashboardSection(
          title: 'My Fault Reports',
          icon: Icons.assignment_outlined,
          accent: accent,
          emptyLabel: 'You have not reported any faults yet',
          rows: const [
            DashboardRow(
              label: 'AST-00412: Printer, Office 3',
              detail: 'Reported 3 days ago',
              status: 'In Progress',
            ),
            DashboardRow(
              label: 'AST-00389: Chair, Office 1',
              detail: 'Reported 1 week ago',
              status: 'Resolved',
            ),
          ],
        ),
      ],
    );
  }
}
