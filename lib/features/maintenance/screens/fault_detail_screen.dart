import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../dashboard/widgets/dashboard_section.dart';
import '../models/fault_report.dart';

/// Read-only information for a fault report selected from the dashboard.
class FaultDetailScreen extends StatelessWidget {
  const FaultDetailScreen({super.key, required this.report});

  final FaultReport report;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusTint = statusColor(context, report.statusLabel);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F8),
      appBar: AppBar(title: const Text('Fault Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FaultSummaryCard(
              assetCode: report.assetCode,
              statusLabel: report.statusLabel,
              statusTint: statusTint,
            ),
            const SizedBox(height: 24),
            Text(
              'REPORT DETAILS',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            _DetailsCard(
              children: [
                _DetailRow(
                  icon: Icons.description_outlined,
                  label: 'Fault description',
                  value: report.description,
                ),
                _DetailRow(
                  icon: Icons.health_and_safety_outlined,
                  label: 'Observed condition',
                  value: report.observedCondition.isNotEmpty
                      ? _titleCase(report.observedCondition)
                      : 'Not provided',
                ),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Reported',
                  value: _formatDate(report.reportedAt),
                  isLast:
                      (report.reportedByName?.isEmpty ?? true) &&
                      (report.reportedByEmail?.isEmpty ?? true),
                ),
                if (report.reportedByName?.isNotEmpty ?? false)
                  _DetailRow(
                    icon: Icons.person_outline,
                    label: 'Reported by',
                    value: report.reportedByName!,
                    isLast: report.reportedByEmail?.isEmpty ?? true,
                  ),
                if (report.reportedByEmail?.isNotEmpty ?? false)
                  _DetailRow(
                    icon: Icons.alternate_email,
                    label: 'Reporter email',
                    value: report.reportedByEmail!,
                    isLast: true,
                  ),
              ],
            ),
            if (report.photoUrl?.isNotEmpty ?? false) ...[
              const SizedBox(height: 16),
              _PhotoCard(photoUrl: report.photoUrl!),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static String _titleCase(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map(
        (word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

class _FaultSummaryCard extends StatelessWidget {
  const _FaultSummaryCard({
    required this.assetCode,
    required this.statusLabel,
    required this.statusTint,
  });

  final String assetCode;
  final String statusLabel;
  final Color statusTint;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9EDEA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: CoreGridBrand.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.report_problem_outlined,
              color: CoreGridBrand.orange,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assetCode.isNotEmpty ? assetCode : 'Asset fault report',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Fault report',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusChip(label: statusLabel, color: statusTint),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Status: $label',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFE9EDEA)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: CoreGridBrand.green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: CoreGridBrand.green),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value.isNotEmpty ? value : 'Not provided',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(color: colors.outlineVariant, height: 1),
      ],
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFE9EDEA)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Photo evidence',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              photoUrl,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 120,
                alignment: Alignment.center,
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: const Text('Photo could not be loaded'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
