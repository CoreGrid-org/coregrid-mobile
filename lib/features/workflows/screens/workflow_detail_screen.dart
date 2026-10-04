import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/ui.dart';
import '../models/agent_workflow.dart';
import '../workflows_providers.dart';
import 'workflow_list_screen.dart';

/// Workflow status and recommendation summary (SRS §3.4: mobile shows the
/// summary, not the full execution trace). Polls until resolved.
/// Route: `/workflows/:id`.
class WorkflowDetailScreen extends ConsumerWidget {
  const WorkflowDetailScreen({super.key, required this.workflowId});

  final String workflowId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflowState = ref.watch(agentWorkflowProvider(workflowId));

    return Scaffold(
      appBar: AppBar(title: const Text('Evaluation')),
      body: AsyncView(
        value: workflowState,
        errorTitle: 'Couldn\'t load this evaluation',
        onRetry: () => ref.invalidate(agentWorkflowProvider(workflowId)),
        data: (value) => _WorkflowStatus(workflow: value),
      ),
    );
  }
}

class _WorkflowStatus extends StatelessWidget {
  const _WorkflowStatus({required this.workflow});

  final AgentWorkflow workflow;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = workflowVisual(workflow);
    final fleet = workflow.fleet;

    return ListView(
      padding: AppSpacing.pageInsets,
      children: [
        Text(workflow.objective, style: context.text.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          workflow.isSingleAsset
              ? 'Asset ${workflow.assetCode} · ${workflow.assetTypeName}'
              : '${workflow.assetTypeName} fleet · ${workflow.categoryName}',
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        ClayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: EntityHeader(
                  icon: icon,
                  iconTone: tone,
                  title: workflowStatusLabel(workflow),
                  subtitle: _statusExplanation(workflow),
                ),
              ),
              if (workflow.isInProgress)
                const LinearProgressIndicator(minHeight: 3),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (workflow.isStopped || workflow.needsRevision)
          Notice(
            tone: workflow.isStopped ? StatusTone.danger : StatusTone.warning,
            title: workflow.isStopped
                ? 'No action will be taken'
                : 'Revision needed',
            message: workflow.failureReason ?? 'No reason was recorded.',
          ),
        if (workflow.recommendation != null && !workflow.isInProgress)
          Notice(
            tone: tone == StatusTone.danger
                ? StatusTone.neutral
                : StatusTone.success,
            icon: Icons.lightbulb_outline,
            title:
                'Recommendation: ${humanizeStatus(workflow.recommendation!)}',
            message: workflow.reason ?? _fleetSummary(fleet),
          ),
        if (!workflow.isSingleAsset && (fleet?.assets.isNotEmpty ?? false))
          _FleetBreakdown(fleet: fleet!),
        const SectionHeader('Details'),
        ListCard(
          children: [
            InfoRow(
              label: 'Approval',
              value: humanizeStatus(workflow.approvalStatus),
            ),
            InfoRow(
              label: 'Impact',
              value: workflow.isHighImpact ? 'High' : 'Standard',
            ),
            if (fleet != null && !workflow.isSingleAsset)
              InfoRow(label: 'Assets evaluated', value: '${fleet.assetCount}'),
            if (workflow.revisionCount > 0)
              InfoRow(label: 'Revisions', value: '${workflow.revisionCount}'),
            InfoRow(
              label: 'Requested',
              value: formatDateTime(workflow.createdAt),
            ),
            if (workflow.completedAt != null)
              InfoRow(
                label: 'Finished',
                value: formatDateTime(workflow.completedAt!),
              ),
            if (workflow.initiatedByEmail != null)
              InfoRow(label: 'Requested by', value: workflow.initiatedByEmail!),
          ],
        ),
        if (workflow.isSingleAsset) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => context.push('/assets/${workflow.assetId}'),
            icon: const Icon(Icons.description_outlined, size: 20),
            label: const Text('Open asset record'),
          ),
        ],
      ],
    );
  }

  static String _statusExplanation(AgentWorkflow w) => switch (w.status) {
    'PLANNING' ||
    'ANALYZING' ||
    'VALIDATING' => 'The agents are working — this page updates automatically.',
    'AWAITING_APPROVAL' =>
      'High-impact recommendation. An Administrator decides in the CoreGrid '
          'web console; this page updates when they do.',
    'COMPLETED_ADVISORY' =>
      'Policy-compliant and low impact, so no approval was needed.',
    'APPROVED' => 'Approved by an Administrator.',
    'REJECTED' => 'Rejected by an Administrator.',
    'REVISION_REQUESTED' => 'No policy-permitted action yet.',
    'FAILED_SAFE' => 'Stopped safely. No asset record was changed.',
    _ => 'Evaluation finished.',
  };

  static String _fleetSummary(FleetEvaluation? fleet) {
    if (fleet == null || fleet.actionCounts.isEmpty) {
      return 'No per-asset breakdown was recorded.';
    }
    final mix = fleet.actionCounts.entries
        .map((e) => '${e.value} ${humanizeStatus(e.key).toLowerCase()}')
        .join(', ');
    final deferred = fleet.deferredCount > 0
        ? ' · ${fleet.deferredCount} deferred'
        : '';
    return 'Across ${fleet.assetCount} assets: $mix$deferred.';
  }
}

/// Fleet evaluations: what the agent recommends for each asset and why, so
/// the officer knows which assets in the field are affected. Each row opens
/// that asset's record. Assets policy didn't clear come first.
class _FleetBreakdown extends StatelessWidget {
  const _FleetBreakdown({required this.fleet});

  final FleetEvaluation fleet;

  static StatusTone _tone(String verdict) => switch (verdict.toUpperCase()) {
    'PASS' => StatusTone.success,
    'NEEDS_REVISION' => StatusTone.warning,
    'FAIL' => StatusTone.danger,
    _ => StatusTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final assets = [
      ...fleet.assets,
    ]..sort((a, b) => _tone(b.verdict).index.compareTo(_tone(a.verdict).index));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Asset by asset · ${assets.length}'),
        ListCard(
          children: [
            for (final a in assets)
              RecordTile(
                icon: Icons.inventory_2_outlined,
                iconTone: _tone(a.verdict),
                title: a.condition.isEmpty
                    ? a.assetCode
                    : '${a.assetCode} · ${humanizeStatus(a.condition)}',
                subtitle: a.reason.isEmpty ? null : a.reason,
                trailing: StatusPill(
                  humanizeStatus(a.action),
                  tone: _tone(a.verdict),
                ),
                onTap: a.assetId == null
                    ? null
                    : () => context.push('/assets/${a.assetId}'),
              ),
          ],
        ),
      ],
    );
  }
}
