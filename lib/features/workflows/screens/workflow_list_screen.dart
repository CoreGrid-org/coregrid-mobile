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
    final groups = [
      ('Needs a decision', workflows.where((w) => w.isAwaitingApproval)),
      ('In progress', workflows.where((w) => w.isInProgress)),
      ('Finished', workflows.where((w) => w.isFinished)),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.pageInsetsFab,
      children: [
        for (final (title, group) in groups)
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
    final recommendation = workflow.recommendation;
    final subtitle = workflow.isInProgress
        ? 'Started ${formatDateTime(workflow.createdAt)}'
        : workflow.isStopped || workflow.needsRevision
        ? (workflow.failureReason ?? workflowStatusLabel(workflow))
        : recommendation != null
        ? 'Recommends ${humanizeStatus(recommendation).toLowerCase()}'
        : 'Completed';

    return RecordTile(
      icon: icon,
      iconTone: tone,
      title: '${workflow.targetLabel} · ${workflow.objective}',
      subtitle: subtitle,
      trailing: StatusPill(workflowStatusLabel(workflow), tone: tone),
      onTap: () => context.push('/workflows/${workflow.id}'),
    );
  }
}

/// A short, officer-friendly name for a workflow's status.
String workflowStatusLabel(AgentWorkflow w) => switch (w.status) {
  'PLANNING' => 'Planning',
  'ANALYZING' => 'Analysing',
  'VALIDATING' => 'Checking policy',
  'AWAITING_APPROVAL' => 'Awaiting approval',
  'APPROVED' => 'Approved',
  'REJECTED' => 'Rejected',
  'COMPLETED_ADVISORY' => 'Completed',
  'REVISION_REQUESTED' => 'Needs revision',
  'FAILED_SAFE' => 'Stopped safely',
  _ => humanizeStatus(w.status),
};

(IconData, StatusTone) workflowVisual(AgentWorkflow w) => switch (w.status) {
  'AWAITING_APPROVAL' => (Icons.pending_actions_outlined, StatusTone.warning),
  'REVISION_REQUESTED' => (Icons.edit_note_outlined, StatusTone.warning),
  'FAILED_SAFE' || 'REJECTED' => (Icons.block_outlined, StatusTone.danger),
  'APPROVED' || 'COMPLETED_ADVISORY' => (Icons.task_alt, StatusTone.success),
  _ => (Icons.autorenew_rounded, StatusTone.info),
};
