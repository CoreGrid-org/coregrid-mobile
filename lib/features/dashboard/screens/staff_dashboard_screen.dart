import 'package:flutter/material.dart';

import '../widgets/dashboard_section.dart';

/// Staff's dashboard body — SRS §2.3.1: what they've reported and its
/// status (FR-033, FR-080, summarised per FR-083). Deliberately narrower
/// than the Officer's — Staff has no verification, maintenance-management or
/// transfer capability. Mock data — see [DashboardScreen]'s banner.
class StaffDashboardBody extends StatelessWidget {
  const StaffDashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => notBuiltYet(context, 'features/scan'),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan / Look Up Asset'),
            ),
            OutlinedButton.icon(
              onPressed: () => notBuiltYet(context, 'features/maintenance'),
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text('Report Fault'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DashboardSection(
          title: 'My Fault Reports',
          icon: Icons.assignment_outlined,
          emptyLabel: 'You haven\'t reported any faults yet',
          rows: const [
            DashboardRow(
              label: 'AST-00412 — Printer, Office 3',
              detail: 'Reported 3 days ago',
              status: 'In Progress',
            ),
            DashboardRow(
              label: 'AST-00389 — Chair, Office 1',
              detail: 'Reported 1 week ago',
              status: 'Resolved',
            ),
          ],
        ),
      ],
    );
  }
}
