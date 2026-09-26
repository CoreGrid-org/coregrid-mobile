import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/api/api_exception.dart';
import '../models/agent_workflow.dart';
import '../workflows_providers.dart';

/// Workflow detail screen — polls status until complete. Route: `/workflows/:id`.
class WorkflowDetailScreen extends ConsumerWidget {
  const WorkflowDetailScreen({super.key, required this.workflowId});

  final String workflowId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflowState = ref.watch(agentWorkflowProvider(workflowId));

    return Scaffold(
      appBar: AppBar(title: const Text('Agent Workflow')),
      body: switch (workflowState) {
        AsyncData(:final value) => _WorkflowStatus(workflow: value),
        AsyncError(:final error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error is ApiException
                  ? error.message
                  : 'Couldn\'t load this workflow.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _WorkflowStatus extends StatelessWidget {
  const _WorkflowStatus({required this.workflow});

  final AgentWorkflow workflow;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${workflow.assetCode}: ${workflow.objective}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Started ${_formatDateTime(workflow.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(_statusIcon(), color: _statusColor(colors)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workflow.status,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (!workflow.isResolved && !workflow.isFailed)
                          const Text('In progress. Updates automatically.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (workflow.isFailed) ...[
            const SizedBox(height: 12),
            _OutcomeCard(
              icon: Icons.error_outline,
              color: colors.error,
              title: 'Evaluation failed',
              body: workflow.failureReason ?? 'No reason was recorded.',
            ),
          ] else if (workflow.isResolved) ...[
            const SizedBox(height: 12),
            _OutcomeCard(
              icon: Icons.check_circle_outline,
              color: colors.primary,
              title: 'Recommendation',
              body:
                  workflow.recommendation ?? 'No recommendation was recorded.',
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(
                  workflow.awaitingApproval
                      ? Icons.hourglass_top_outlined
                      : Icons.verified_outlined,
                ),
                title: const Text('Approval status'),
                subtitle: Text(workflow.approvalStatus),
                trailing: workflow.isHighImpact
                    ? const Chip(
                        label: Text('High impact'),
                        visualDensity: VisualDensity.compact,
                      )
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _statusIcon() {
    if (workflow.isFailed) return Icons.error_outline;
    if (workflow.isResolved) return Icons.task_alt;
    return Icons.hourglass_top_outlined;
  }

  Color _statusColor(ColorScheme colors) {
    if (workflow.isFailed) return colors.error;
    if (workflow.isResolved) return colors.primary;
    return colors.onSurfaceVariant;
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.08),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(body),
      ),
    );
  }
}
