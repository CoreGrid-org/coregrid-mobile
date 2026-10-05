import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/ui.dart';
import '../models/campaign_scope_assets.dart';
import '../models/verification_campaign.dart';
import '../models/verification_task.dart';
import '../verification_providers.dart';
import '../verify_flow.dart';
import 'verification_task_list_screen.dart';

/// One verification campaign: its period, what it covers and progress, plus
/// the officer's checklist for it — what's still to verify, grouped by where
/// each asset is registered (each row with its own scan button), and what's
/// done. "Scan to verify" here checks every label against this campaign. No edit/close/report actions —
/// campaign management is React-only (SRS §3.4).
class CampaignDetailScreen extends ConsumerWidget {
  const CampaignDetailScreen({super.key, required this.campaignId});

  final String campaignId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaign = ref.watch(verificationCampaignProvider(campaignId));
    final loaded = campaign.asData?.value;
    final active = loaded?.status == CampaignStatus.active;

    return Scaffold(
      appBar: AppBar(title: const Text('Campaign')),
      floatingActionButton: active
          ? FloatingActionButton.extended(
              onPressed: () => scanForCampaign(context, ref, loaded!),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan to verify'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(myVerificationTasksProvider);
          ref.invalidate(campaignScopeAssetsProvider(campaignId));
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
    // Type and registered location per asset; the checklist still renders
    // (ungrouped) while this loads or if it fails.
    final scopeAssets = ref
        .watch(campaignScopeAssetsProvider(campaign.id))
        .asData
        ?.value;

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
          ],
        ),
        _WhatToScan(campaign: campaign),
        switch (myTasks) {
          AsyncData(:final value) => _Checklist(
            tasks: value.where((t) => t.campaignId == campaign.id).toList(),
            scopeAssets: scopeAssets,
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

/// What this campaign is checking, spelled out from its scope filters, so
/// the officer knows which kind of asset to look for and where.
class _WhatToScan extends StatelessWidget {
  const _WhatToScan({required this.campaign});

  final VerificationCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final rows = [
      if (campaign.scopeAssetTypeName case final v? when v.isNotEmpty)
        (Icons.category_outlined, 'Asset type', v),
      if (campaign.scopeAssetCategoryName case final v? when v.isNotEmpty)
        (Icons.folder_outlined, 'Category', v),
      if (campaign.scopeLocationName case final v? when v.isNotEmpty)
        (Icons.place_outlined, 'Location', v),
      if (campaign.scopeDepartmentName case final v? when v.isNotEmpty)
        (Icons.apartment_outlined, 'Department', v),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('What to scan'),
        ListCard(
          children: [
            if (rows.isEmpty)
              const InfoRow(
                icon: Icons.inventory_2_outlined,
                label: 'Covers',
                value: 'Every registered asset in the organisation',
              )
            else
              for (final (icon, label, value) in rows)
                InfoRow(icon: icon, label: label, value: value),
          ],
        ),
      ],
    );
  }
}

/// The officer's own tasks in this campaign as a checklist: still to verify
/// (grouped by registered location, overdue/soonest first) and already
/// verified.
class _Checklist extends StatelessWidget {
  const _Checklist({required this.tasks, this.scopeAssets});

  final List<VerificationTask> tasks;
  final CampaignScopeAssets? scopeAssets;

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

    String? typeOf(VerificationTask t) =>
        scopeAssets?[t.assetId]?.assetTypeName;

    // Group by registered location so the officer can walk one place at a
    // time. Only once the asset details are in — until then, a flat list.
    final byLocation = <String, List<VerificationTask>>{};
    if (scopeAssets != null) {
      for (final t in toVerify) {
        final location = scopeAssets![t.assetId]?.locationName;
        byLocation
            .putIfAbsent(
              location == null || location.isEmpty
                  ? 'Location not on record'
                  : location,
              () => [],
            )
            .add(t);
      }
    }
    final locations = byLocation.keys.toList()..sort();

    TaskTile tile(VerificationTask t) =>
        TaskTile(task: t, showCampaign: false, assetTypeName: typeOf(t));

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
              message:
                  'These are the assets you need to find. Go to each '
                  'location, find the asset and scan its label — Scan to '
                  'verify tells you if a label isn\'t part of this campaign.',
            ),
          ),
          SectionHeader(
            'To verify · ${toVerify.length}',
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.sm,
            ),
          ),
          if (locations.isEmpty)
            ListCard(children: [for (final t in toVerify) tile(t)])
          else
            for (final location in locations) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        '$location · ${byLocation[location]!.length}',
                        style: context.mutedSmall,
                      ),
                    ),
                  ],
                ),
              ),
              ListCard(
                children: [for (final t in byLocation[location]!) tile(t)],
              ),
            ],
        ],
        if (verified.isNotEmpty) ...[
          SectionHeader('Verified · ${verified.length}'),
          ListCard(children: [for (final t in verified) tile(t)]),
        ],
      ],
    );
  }
}
