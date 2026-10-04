import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/ui.dart';
import '../models/verification_campaign.dart';
import '../models/verification_task.dart';
import '../verification_providers.dart';
import '../verify_flow.dart';
import 'verification_task_list_screen.dart';

/// One verification campaign: its period, scope and progress, plus the
/// officer's checklist for it — what's still to verify (each row with its
/// own scan button) and what's done. No edit/close/report actions —
/// campaign management is React-only (SRS §3.4).
class CampaignDetailScreen extends ConsumerWidget {
  const CampaignDetailScreen({super.key, required this.campaignId});

  final String campaignId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaign = ref.watch(verificationCampaignProvider(campaignId));
    final active = campaign.asData?.value.status == CampaignStatus.active;

    return Scaffold(
      appBar: AppBar(title: const Text('Campaign')),
      floatingActionButton: active
          ? FloatingActionButton.extended(
              onPressed: () => scanToVerify(context, ref),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan to verify'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(myVerificationTasksProvider);
          return ref.refresh(verificationCampaignProvider(campaignId).future);
        },
        child: AsyncView(
          value: campaign,
          errorTitle: 'Couldn\'t load this campaign',
          onRetry: () =>
              ref.invalidate(verificationCampaignProvider(campaignId)),
          data: (value) => _Body(campaign: value),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.campaign});

  final VerificationCampaign campaign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myTasks = ref.watch(myVerificationTasksProvider);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.pageInsetsFab,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(campaign.name, style: context.text.headlineSmall),
            ),
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: StatusPill(campaign.status.apiValue),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        ClayCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CampaignProgressBar(campaign: campaign),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Metric(value: '${campaign.taskCount}', label: 'Assets'),
                    Metric(
                      value: '${campaign.completedTaskCount}',
                      label: 'Verified',
                      tone: StatusTone.success,
                    ),
                    Metric(
                      value: '${campaign.openDiscrepancyCount}',
                      label: 'Open issues',
                      tone: StatusTone.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ListCard(
          children: [
            InfoRow(
              icon: Icons.event_outlined,
              label: 'Period',
              value:
                  '${formatDate(campaign.periodStart)} – '
                  '${formatDate(campaign.periodEnd)}',
            ),
            InfoRow(
              icon: Icons.filter_alt_outlined,
              label: 'Scope',
              value: campaign.scopeSummary,
            ),
          ],
        ),
        switch (myTasks) {
          AsyncData(:final value) => _Checklist(
            tasks: value.where((t) => t.campaignId == campaign.id).toList(),
          ),
          AsyncError(:final error) => Padding(
            padding: AppSpacing.sectionGap,
            child: Notice(
              tone: StatusTone.danger,
              message: errorMessageFor(error),
            ),
          ),
          _ => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: LoadingView(),
          ),
        },
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Campaigns are planned and closed in the CoreGrid web console.',
          textAlign: TextAlign.center,
          style: context.mutedSmall,
        ),
      ],
    );
  }
}

/// The officer's own tasks in this campaign as a checklist: still to verify
/// (overdue first, then by due date) and already verified.
class _Checklist extends StatelessWidget {
  const _Checklist({required this.tasks});

  final List<VerificationTask> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Padding(
        padding: AppSpacing.sectionGap,
        child: Notice(
          message: 'None of this campaign\'s assets are assigned to you.',
        ),
      );
    }

    final toVerify = tasks.where((t) => t.isPending).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final verified = tasks.where((t) => !t.isPending).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Your assets · ${verified.length} of ${tasks.length} verified',
        ),
        if (toVerify.isEmpty)
          const Notice(
            tone: StatusTone.success,
            message: 'You\'ve verified every asset assigned to you here.',
          )
        else ...[
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: Notice(
              icon: Icons.qr_code_scanner,
              message: 'Go to each asset and tap its scan button to verify it.',
            ),
          ),
          SectionHeader(
            'To verify · ${toVerify.length}',
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.sm,
            ),
          ),
          ListCard(
            children: [
              for (final t in toVerify) TaskTile(task: t, showCampaign: false),
            ],
          ),
        ],
        if (verified.isNotEmpty) ...[
          SectionHeader('Verified · ${verified.length}'),
          ListCard(
            children: [
              for (final t in verified) TaskTile(task: t, showCampaign: false),
            ],
          ),
        ],
      ],
    );
  }
}
