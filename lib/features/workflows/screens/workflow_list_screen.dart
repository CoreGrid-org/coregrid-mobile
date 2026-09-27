import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/ui.dart';
import '../models/agent_workflow.dart';
import '../workflows_providers.dart';

/// Agent workflow list (FR-067) — the Workflows tab. Route: `/workflows`.
class WorkflowListScreen extends ConsumerWidget {
  const WorkflowListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflows = ref.watch(agentWorkflowsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Workflows')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/workflows/new'),
        icon: const Icon(Icons.auto_awesome_outlined),
        label: const Text('Request Evaluation'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(agentWorkflowsProvider.future),
        child: AsyncView(
          value: workflows,
          errorTitle: 'Couldn\'t load workflows',
          onRetry: () => ref.invalidate(agentWorkflowsProvider),
          isEmpty: (value) => value.isEmpty,
          empty: const MessageView(
            icon: Icons.smart_toy_outlined,
            title: 'No agent evaluations yet',
            message:
                'Ask the CoreGrid agent whether an asset should be repaired, '
                'replaced or disposed of.',
          ),
          data: (value) => _WorkflowList(workflows: value),
        ),
      ),
    );
  }
}

class _WorkflowList extends StatelessWidget {
  const _WorkflowList({required this.workflows});

  final List<AgentWorkflow> workflows;

  @override
  Widget build(BuildContext context) {
    final running = workflows
        .where((w) => !w.isResolved && !w.isFailed)
        .toList();
    final done = workflows.where((w) => w.isResolved || w.isFailed).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.pageInsetsFab,
      children: [
        for (final (title, group) in [
          ('In progress', running),
          ('Finished', done),
        ])
          if (group.isNotEmpty) ...[
            SectionHeader(
              '$title · ${group.length}',
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.sm,
              ),
            ),
            ListCard(children: [for (final w in group) WorkflowTile(w)]),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}

/// One workflow row — shared with the dashboard.
class WorkflowTile extends StatelessWidget {
  const WorkflowTile(this.workflow, {super.key});

  final AgentWorkflow workflow;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = workflowVisual(workflow);
    final subtitle = workflow.isFailed
        ? (workflow.failureReason ?? 'Evaluation failed')
        : workflow.isResolved
        ? (workflow.recommendation ?? 'Completed')
        : 'Started ${formatDateTime(workflow.createdAt)}';

    return RecordTile(
      icon: icon,
      iconTone: tone,
      title: '${workflow.assetCode} · ${workflow.objective}',
      subtitle: subtitle,
      trailing: StatusPill(humanizeStatus(workflow.status), tone: tone),
      onTap: () => context.push('/workflows/${workflow.id}'),
    );
  }
}

(IconData, StatusTone) workflowVisual(AgentWorkflow w) {
  if (w.isFailed) return (Icons.error_outline, StatusTone.danger);
  if (w.isResolved) {
    return w.awaitingApproval
        ? (Icons.pending_actions_outlined, StatusTone.warning)
        : (Icons.task_alt, StatusTone.success);
  }
  return (Icons.autorenew_rounded, StatusTone.info);
}
