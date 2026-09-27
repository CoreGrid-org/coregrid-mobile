import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/ui.dart';
import '../../assets_providers.dart';
import '../../models/asset/asset_history_entry.dart';
import '../../models/asset/asset_maintenance_history.dart';

/// Repairs completed / last repair / total cost, from the maintenance
/// history endpoint.
class AssetRepairSummary extends ConsumerWidget {
  const AssetRepairSummary({super.key, required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(assetMaintenanceHistoryProvider(assetId));
    return switch (history) {
      AsyncData(:final value) => _RepairSummaryContent(summary: value),
      AsyncError() => const Notice(message: 'Repair summary unavailable.'),
      _ => const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: LinearProgressIndicator(),
        ),
      ),
    };
  }
}

class _RepairSummaryContent extends StatelessWidget {
  const _RepairSummaryContent({required this.summary});

  final AssetMaintenanceHistory summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Metric(value: summary.repairCount.toString(), label: 'Repairs'),
            Metric(
              value: summary.lastRepairDate == null
                  ? 'None'
                  : formatDate(summary.lastRepairDate!),
              label: 'Last repair',
            ),
            Metric(
              value: formatMoney(summary.totalRepairCost),
              label: 'Repair cost',
            ),
          ],
        ),
      ),
    );
  }
}

/// The asset's lifecycle history as a vertical timeline.
class AssetHistorySection extends ConsumerWidget {
  const AssetHistorySection({super.key, required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(assetHistoryProvider(assetId));
    return switch (history) {
      AsyncData(:final value) when value.isEmpty => const Notice(
        message: 'No history recorded yet.',
      ),
      AsyncData(:final value) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            children: [
              for (var i = 0; i < value.length; i++)
                AssetHistoryTile(
                  entry: value[i],
                  isLast: i == value.length - 1,
                ),
            ],
          ),
        ),
      ),
      AsyncError(:final error) => Notice(
        tone: StatusTone.danger,
        message: errorMessageFor(error, fallback: 'Couldn\'t load history.'),
      ),
      _ => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class AssetHistoryTile extends StatelessWidget {
  const AssetHistoryTile({super.key, required this.entry, this.isLast = false});

  final AssetHistoryEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: context.colors.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.description,
                    style: context.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      formatDateTime(entry.createdAt),
                      if (entry.actorEmail != null) entry.actorEmail!,
                    ].join(' · '),
                    style: context.mutedSmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
