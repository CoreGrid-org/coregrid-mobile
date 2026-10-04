import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/auth/me_provider.dart';
import '../../../shared/widgets/ui.dart';
import '../models/agent_workflow.dart';
import '../workflows_providers.dart';

/// Agent workflow list (FR-067) — the Workflows tab. Route: `/workflows`.
///
/// Opens on the officer's own requests ("Mine") with "Everyone" one tap
/// away — the API returns the organisation's evaluations, and the officer
/// mostly cares about the ones they're waiting on.
class WorkflowListScreen extends ConsumerStatefulWidget {
  const WorkflowListScreen({super.key});

  @override
  ConsumerState<WorkflowListScreen> createState() => _WorkflowListScreenState();
}

class _WorkflowListScreenState extends ConsumerState<WorkflowListScreen> {
  bool _mineOnly = true;

  @override
  Widget build(BuildContext context) {
    final workflows = ref.watch(agentWorkflowsProvider);
    final myId = ref.watch(meProvider).asData?.value.id;
    // Until the profile loads there's nothing to match "Mine" against.
    final canFilter = myId != null && myId.isNotEmpty;
    final mineOnly = _mineOnly && canFilter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workflows'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.md,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: true,
                    label: const Text('Mine'),
                    icon: const Icon(Icons.person_outline),
                    enabled: canFilter,
                  ),
                  const ButtonSegment(
                    value: false,
                    label: Text('Everyone'),
                    icon: Icon(Icons.groups_outlined),
                  ),
                ],
                selected: {mineOnly},
                onSelectionChanged: (v) => setState(() => _mineOnly = v.first),
              ),
            ),
          ),
        ),
      ),
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
          data: (value) {
            final shown = mineOnly
                ? value.where((w) => w.initiatedByUserId == myId).toList()
                : value;
            if (shown.isEmpty) {
              return MessageView(
                icon: Icons.person_search_outlined,
                title: 'You haven\'t requested any evaluations',
                message:
                    'Request one from an asset\'s record, or see what '
                    'others have asked the agent.',
                action: OutlinedButton(
                  onPressed: () => setState(() => _mineOnly = false),
                  child: const Text('See everyone\'s'),
                ),
              );
            }
            return _WorkflowList(workflows: shown);
          },
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
      (
        'Needs a decision',
        workflows.where((w) => w.isAwaitingApproval).toList(),
        StatusTone.warning,
      ),
      (
        'In progress',
        workflows.where((w) => w.isInProgress).toList(),
        StatusTone.info,
      ),
      (
        'Finished',
        workflows.where((w) => w.isFinished).toList(),
        StatusTone.success,
      ),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.pageInsetsFab,
      children: [
        StatRow(
          cards: [
            for (final (title, group, tone) in groups)
              StatCard(label: title, value: group.length, tone: tone),
          ],
        ),
        for (final (title, group, _) in groups)
          if (group.isNotEmpty) ...[
            SectionHeader('$title · ${group.length}'),
            ListCard(children: [for (final w in group) WorkflowTile(w)]),
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
