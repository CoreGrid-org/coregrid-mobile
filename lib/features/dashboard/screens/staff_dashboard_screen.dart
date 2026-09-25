import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../widgets/dashboard_section.dart';
import '../widgets/my_fault_reports_section.dart';

/// Staff's dashboard body. SRS §2.3.1: what they've reported and its
/// status (FR-033, FR-080, summarised per FR-083). Deliberately narrower
/// than the Officer's; Staff has no verification, workflows or
/// transfer capability. Matches the inventory officer dashboard UI style with
/// orange brand accents.
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
            // FR-025: manual code entry, always available
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
            // FR-080: staff member can report fault
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
