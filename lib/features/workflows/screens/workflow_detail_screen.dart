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
    final running = !workflow.isResolved && !workflow.isFailed;

    return ListView(
      padding: AppSpacing.pageInsets,
      children: [
        Text(workflow.objective, style: context.text.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Asset ${workflow.assetCode}',
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: EntityHeader(
                  icon: icon,
                  iconTone: tone,
                  title: humanizeStatus(workflow.status),
                  subtitle: running
                      ? 'The agent is working — this page updates '
                            'automatically.'
                      : 'Evaluation finished.',
                ),
              ),
              if (running) const LinearProgressIndicator(minHeight: 3),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (workflow.isFailed)
          Notice(
            tone: StatusTone.danger,
            title: 'Evaluation failed',
            message: workflow.failureReason ?? 'No reason was recorded.',
          )
        else if (workflow.isResolved)
          Notice(
            tone: StatusTone.success,
            icon: Icons.lightbulb_outline,
            title: 'Recommendation',
            message:
                workflow.recommendation ?? 'No recommendation was recorded.',
          ),
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
        if (workflow.awaitingApproval) ...[
          const SizedBox(height: AppSpacing.md),
          const Notice(
            message:
                'High-impact recommendations are approved by an '
                'administrator in the CoreGrid web console.',
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => context.push('/assets/${workflow.assetId}'),
          icon: const Icon(Icons.description_outlined, size: 20),
          label: const Text('Open asset record'),
        ),
      ],
    );
  }
}
