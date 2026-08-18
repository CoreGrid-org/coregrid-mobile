import 'package:flutter/material.dart';

import '../widgets/dashboard_section.dart';

/// Inventory Officer's dashboard body — SRS §2.3.1: verification tasks,
/// maintenance assigned to them, and transfers awaiting their confirmation
/// (FR-058, FR-037, FR-046, summarised per FR-083). Mock data — see
/// [DashboardScreen]'s banner.
class OfficerDashboardBody extends StatelessWidget {
  const OfficerDashboardBody({super.key});

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
              label: const Text('Scan Asset'),
            ),
            OutlinedButton.icon(
              onPressed: () => notBuiltYet(context, 'features/transfers'),
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Raise Transfer'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DashboardSection(
          title: 'Verification Tasks Due',
          icon: Icons.fact_check_outlined,
          rows: const [
            DashboardRow(
              label: 'AST-00231 — Generator, Workshop 2',
              detail: 'Due today',
              status: 'Pending',
            ),
            DashboardRow(
              label: 'AST-00198 — Forklift, Store 1',
              detail: 'Due in 2 days',
              status: 'Pending',
            ),
          ],
        ),
        DashboardSection(
          title: 'Maintenance Assigned to Me',
          icon: Icons.build_outlined,
          rows: const [
            DashboardRow(
              label: 'AST-00147 — Air Compressor',
              detail: 'Corrective, priority: High',
              status: 'In Progress',
            ),
          ],
        ),
        DashboardSection(
          title: 'Transfers Awaiting My Confirmation',
          icon: Icons.move_to_inbox_outlined,
          rows: const [
            DashboardRow(
              label: 'AST-00305 — Laptop, from Finance Dept.',
              detail: 'Requested 1 day ago',
              status: 'In Transit',
            ),
          ],
        ),
      ],
    );
  }
}
