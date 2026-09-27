import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/ui.dart';
import '../models/fault_report.dart';

/// Read-only view of one of the user's fault reports, with where it is in
/// the repair lifecycle. Route: `/maintenance/:id` (report passed as extra).
class FaultDetailScreen extends StatelessWidget {
  const FaultDetailScreen({super.key, required this.report});

  final FaultReport report;

  /// 0 = reported, 1 = being worked on, 2 = closed.
  int get _stage => report.isOpen
      ? 0
      : report.isInProgress
      ? 1
      : 2;

  @override
  Widget build(BuildContext context) {
    final tone = StatusTone.of(report.statusLabel);

    return Scaffold(
      appBar: AppBar(title: const Text('Fault report')),
      body: ListView(
        padding: AppSpacing.pageInsets,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconTile(
                        report.isPreventive
                            ? Icons.event_repeat_outlined
                            : Icons.build_circle_outlined,
                        tone: tone,
                        size: 48,
                      ),
                      const Spacer(),
                      Semantics(
                        label: 'Status: ${report.statusLabel}',
                        child: StatusPill(report.statusLabel, tone: tone),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(report.description, style: context.text.titleMedium),
                  const SizedBox(height: AppSpacing.lg),
                  _Progress(stage: _stage),
                ],
              ),
            ),
          ),
          const SectionHeader('Details'),
          ListCard(
            children: [
              InfoRow(
                icon: Icons.qr_code_2,
                label: 'Asset',
                value: report.assetCode.isNotEmpty
                    ? report.assetCode
                    : 'Not provided',
              ),
              InfoRow(
                icon: Icons.health_and_safety_outlined,
                label: 'Condition',
                value: report.observedCondition.isNotEmpty
                    ? humanizeStatus(report.observedCondition)
                    : 'Not provided',
              ),
              InfoRow(
                icon: Icons.event_outlined,
                label: 'Reported',
                value: formatDate(report.reportedAt),
              ),
              if (report.reportedByName?.isNotEmpty ?? false)
                InfoRow(
                  icon: Icons.person_outline,
                  label: 'Reported by',
                  value: report.reportedByName!,
                ),
              if (report.reportedByEmail?.isNotEmpty ?? false)
                InfoRow(
                  icon: Icons.alternate_email,
                  label: 'Email',
                  value: report.reportedByEmail!,
                ),
            ],
          ),
          if (report.photoUrl?.isNotEmpty ?? false) ...[
            const SectionHeader('Photo evidence'),
            Card(
              child: Image.network(
                report.photoUrl!,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  height: 120,
                  child: Center(child: Text('Photo could not be loaded')),
                ),
              ),
            ),
          ],
          if (report.assetId.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: () => context.push('/assets/${report.assetId}'),
              icon: const Icon(Icons.description_outlined, size: 20),
              label: const Text('Open asset record'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Three-step Reported → In progress → Resolved tracker.
class _Progress extends StatelessWidget {
  const _Progress({required this.stage});

  final int stage;

  static const _labels = ['Reported', 'In progress', 'Resolved'];

  @override
  Widget build(BuildContext context) {
    final active = context.colors.primary;
    final idle = context.colors.outlineVariant;

    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i <= stage ? active : idle,
              ),
            ),
          Column(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: i <= stage ? active : idle,
                child: i < stage
                    ? Icon(
                        Icons.check,
                        size: 14,
                        color: context.colors.onPrimary,
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _labels[i],
                style: context.text.labelSmall?.copyWith(
                  color: i <= stage
                      ? context.colors.onSurface
                      : context.colors.onSurfaceVariant,
                  fontWeight: i == stage ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
