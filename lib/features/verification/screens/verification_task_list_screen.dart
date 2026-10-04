import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/ui.dart';
import '../models/verification_campaign.dart';
import '../models/verification_task.dart';
import '../verification_providers.dart';
import '../verify_flow.dart';

enum _VerifyView { tasks, campaigns }

/// The Verify tab (FR-058): the officer's assigned tasks grouped by urgency,
/// and — as read-only context — the campaigns those tasks belong to.
class VerificationTaskListScreen extends ConsumerStatefulWidget {
  const VerificationTaskListScreen({super.key, this.showCampaigns = false});

  /// Opens on the Campaigns segment (`/verification?view=campaigns`).
  final bool showCampaigns;

  @override
  ConsumerState<VerificationTaskListScreen> createState() =>
      _VerificationTaskListScreenState();
}

class _VerificationTaskListScreenState
    extends ConsumerState<VerificationTaskListScreen> {
  late _VerifyView _view = widget.showCampaigns
      ? _VerifyView.campaigns
      : _VerifyView.tasks;

  @override
  void didUpdateWidget(covariant VerificationTaskListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showCampaigns != oldWidget.showCampaigns) {
      _view = widget.showCampaigns ? _VerifyView.campaigns : _VerifyView.tasks;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => scanToVerify(context, ref),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan to verify'),
      ),
      appBar: AppBar(
        title: const Text('Verification'),
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
              child: SegmentedButton<_VerifyView>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _VerifyView.tasks,
                    label: Text('My tasks'),
                    icon: Icon(Icons.checklist_rounded),
                  ),
                  ButtonSegment(
                    value: _VerifyView.campaigns,
                    label: Text('Campaigns'),
                    icon: Icon(Icons.flag_outlined),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (s) => setState(() => _view = s.first),
              ),
            ),
          ),
        ),
      ),
      body: switch (_view) {
        _VerifyView.tasks => const _TasksView(),
        _VerifyView.campaigns => const _CampaignsView(),
      },
    );
  }
}

// ─── My tasks ───────────────────────────────────────────────────────────────

class _TasksView extends ConsumerWidget {
  const _TasksView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(myVerificationTasksProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(myVerificationTasksProvider.future),
      child: AsyncView(
        value: tasks,
        errorTitle: 'Couldn\'t load your tasks',
        onRetry: () => ref.invalidate(myVerificationTasksProvider),
        isEmpty: (value) => value.isEmpty,
        empty: const MessageView(
          icon: Icons.task_alt_rounded,
          tone: StatusTone.success,
          title: 'All clear',
          message: 'No verification tasks assigned to you.',
        ),
        data: (value) => _TaskGroups(tasks: value),
      ),
    );
  }
}

class _TaskGroups extends StatelessWidget {
  const _TaskGroups({required this.tasks});

  final List<VerificationTask> tasks;

  @override
  Widget build(BuildContext context) {
    final overdue = tasks.where((t) => t.isOverdue).toList();
    final upcoming = tasks.where((t) => t.isPending && !t.isOverdue).toList();
    final completed = tasks.where((t) => !t.isPending).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.pageInsetsFab,
      children: [
        StatRow(
          cards: [
            StatCard(
              label: 'Overdue',
              value: overdue.length,
              tone: StatusTone.danger,
            ),
            StatCard(
              label: 'To do',
              value: upcoming.length,
              tone: StatusTone.warning,
            ),
            StatCard(
              label: 'Done',
              value: completed.length,
              tone: StatusTone.success,
            ),
          ],
        ),
        for (final (title, group) in [
          ('Overdue', overdue),
          ('Upcoming', upcoming),
          ('Completed', completed),
        ])
          if (group.isNotEmpty) ...[
            SectionHeader('$title · ${group.length}'),
            ListCard(children: [for (final t in group) TaskTile(task: t)]),
          ],
      ],
    );
  }
}

/// One verification task row — shared with the campaign detail screen.
class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, this.showCampaign = true});

  final VerificationTask task;
  final bool showCampaign;

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon) = switch (task) {
      _ when !task.isPending => (
        'Completed',
        StatusTone.success,
        Icons.check_circle_outline,
      ),
      _ when task.isOverdue => (
        'Overdue',
        StatusTone.danger,
        Icons.assignment_late_outlined,
      ),
      _ => ('Pending', StatusTone.warning, Icons.assignment_outlined),
    };
    final when = task.isPending
        ? describeDue(task.dueDate)
        : 'Verified ${formatDate(task.completedAt ?? task.dueDate)}';

    // A task still to do gets its own scan button — scan the label right
    // from the list and land on the task with identity confirmed (FR-059).
    return RecordTile(
      icon: icon,
      iconTone: tone,
      title: '${task.assetCode} · ${task.assetName}',
      subtitle: showCampaign ? '${task.campaignName} · $when' : when,
      trailing: task.isPending
          ? IconButton.filledTonal(
              onPressed: () => scanTaskAsset(context, task),
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scan ${task.assetCode}',
            )
          : StatusPill(label, tone: tone),
      showChevron: !task.isPending,
      onTap: () => context.push('/verification/${task.id}'),
    );
  }
}

// ─── Campaigns (read-only) ──────────────────────────────────────────────────

class _CampaignsView extends ConsumerWidget {
  const _CampaignsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaigns = ref.watch(verificationCampaignsProvider);
    final myTasks = ref.watch(myVerificationTasksProvider).asData?.value ?? [];

    return RefreshIndicator(
      onRefresh: () => ref.refresh(verificationCampaignsProvider.future),
      child: AsyncView(
        value: campaigns,
        errorTitle: 'Couldn\'t load campaigns',
        onRetry: () => ref.invalidate(verificationCampaignsProvider),
        isEmpty: (value) => value.isEmpty,
        empty: const MessageView(
          icon: Icons.flag_outlined,
          title: 'No campaigns yet',
          message:
              'Verification campaigns are planned in the CoreGrid web '
              'console. They\'ll appear here once one is running.',
        ),
        data: (value) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.pageInsetsFab,
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) => CampaignCard(
            campaign: value[i],
            myTaskCount: myTasks
                .where((t) => t.campaignId == value[i].id && t.isPending)
                .length,
          ),
        ),
      ),
    );
  }
}

class CampaignCard extends StatelessWidget {
  const CampaignCard({
    super.key,
    required this.campaign,
    required this.myTaskCount,
  });

  final VerificationCampaign campaign;
  final int myTaskCount;

  @override
  Widget build(BuildContext context) {
    final muted = context.mutedSmall;

    return ClayCard(
      child: InkWell(
        onTap: () => context.push('/campaigns/${campaign.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(campaign.name, style: context.text.titleMedium),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusPill(campaign.status.apiValue),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${formatDate(campaign.periodStart)} – '
                '${formatDate(campaign.periodEnd)} · ${campaign.scopeSummary}',
                style: muted,
              ),
              const SizedBox(height: AppSpacing.lg),
              CampaignProgressBar(campaign: campaign),
              if (myTaskCount > 0 || campaign.openDiscrepancyCount > 0) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (myTaskCount > 0)
                      StatusPill(
                        '$myTaskCount assigned to you',
                        tone: StatusTone.info,
                      ),
                    if (campaign.openDiscrepancyCount > 0)
                      StatusPill(
                        '${campaign.openDiscrepancyCount} open '
                        '${campaign.openDiscrepancyCount == 1 ? 'discrepancy' : 'discrepancies'}',
                        tone: StatusTone.warning,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "12 of 18 verified" + percentage over a rounded progress bar.
class CampaignProgressBar extends StatelessWidget {
  const CampaignProgressBar({super.key, required this.campaign});

  final VerificationCampaign campaign;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${campaign.completedTaskCount} of ${campaign.taskCount} verified',
                style: context.mutedSmall,
              ),
            ),
            Text(
              '${(campaign.progress * 100).round()}%',
              style: context.text.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: campaign.progress,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
