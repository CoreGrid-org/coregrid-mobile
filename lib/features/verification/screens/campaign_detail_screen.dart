import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/ui.dart';
import '../models/verification_campaign.dart';
import '../verification_providers.dart';
import 'verification_task_list_screen.dart';

/// Read-only view of one verification campaign: its period, scope and
/// progress, plus the officer's own tasks in it. No edit/close/report
/// actions — campaign management is React-only (SRS §3.4).
class CampaignDetailScreen extends ConsumerWidget {
  const CampaignDetailScreen({super.key, required this.campaignId});

  final String campaignId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaign = ref.watch(verificationCampaignProvider(campaignId));

    return Scaffold(
      appBar: AppBar(title: const Text('Campaign')),
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
      padding: AppSpacing.pageInsets,
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
        Card(
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
        const SectionHeader('Your tasks'),
        switch (myTasks) {
          AsyncData(:final value) => () {
            final mine = value
                .where((t) => t.campaignId == campaign.id)
                .toList();
            if (mine.isEmpty) {
              return const Notice(
                message: 'None of this campaign\'s assets are assigned to you.',
              );
            }
            return ListCard(
              children: [
                for (final t in mine) TaskTile(task: t, showCampaign: false),
              ],
            );
          }(),
          AsyncError(:final error) => Notice(
            tone: StatusTone.danger,
            message: errorMessageFor(error),
          ),
          _ => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
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
