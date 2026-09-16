import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/api/api_exception.dart';
import '../../assets_providers.dart';
import '../../models/asset/asset_history_entry.dart';
import '../../models/asset/asset_maintenance_history.dart';

class AssetDetailSection extends StatelessWidget {
  const AssetDetailSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  static const orange = Color(0xFFFF5A00);
  static const lightOrange = Color(0xFFFFF0E8);
  static const darkText = Color(0xFF202625);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: lightOrange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 26, color: orange),
              ),
              const SizedBox(width: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class AssetDetailRow extends StatelessWidget {
  const AssetDetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  static const darkText = Color(0xFF202625);
  static const secondaryText = Color(0xFF59635F);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: darkText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AssetRepairSummary extends ConsumerWidget {
  const AssetRepairSummary({super.key, required this.assetId});

  final String assetId;

  static const orange = Color(0xFFFF5A00);
  static const secondaryText = Color(0xFF59635F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(assetMaintenanceHistoryProvider(assetId));
    return history.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 16),
        child: LinearProgressIndicator(color: orange),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          'Repair summary unavailable.',
          style: TextStyle(color: secondaryText),
        ),
      ),
      data: (summary) => _RepairSummaryContent(summary: summary),
    );
  }
}

class _RepairSummaryContent extends StatelessWidget {
  const _RepairSummaryContent({required this.summary});

  final AssetMaintenanceHistory summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0E8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Repair summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _RepairSummaryRow(
              label: 'Repairs completed',
              value: summary.repairCount.toString(),
            ),
            _RepairSummaryRow(
              label: 'Last repair',
              value: summary.lastRepairDate == null
                  ? 'No completed repairs'
                  : DateFormat.yMMMMd().format(summary.lastRepairDate!),
            ),
            _RepairSummaryRow(
              label: 'Total repair cost',
              value: NumberFormat.decimalPatternDigits(decimalDigits: 2)
                  .format(summary.totalRepairCost),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepairSummaryRow extends StatelessWidget {
  const _RepairSummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class AssetStatusTag extends StatelessWidget {
  const AssetStatusTag({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  static const orange = Color(0xFFFF5A00);
  static const lightOrange = Color(0xFFFFF0E8);
  static const darkText = Color(0xFF202625);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: lightOrange,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: orange),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: darkText,
            ),
          ),
        ],
      ),
    );
  }
}

class AssetHistorySection extends StatelessWidget {
  const AssetHistorySection({super.key, required this.assetId});

  final String assetId;

  static const orange = Color(0xFFFF5A00);
  static const lightOrange = Color(0xFFFFF0E8);
  static const darkText = Color(0xFF202625);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(26, 0, 26, 20),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: lightOrange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.history_rounded, size: 26, color: orange),
          ),
          title: const Text(
            'History',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: darkText,
            ),
          ),
          iconColor: orange,
          collapsedIconColor: Color(0xFF59635F),
          children: [
            Consumer(
              builder: (context, ref, _) {
                final history = ref.watch(assetHistoryProvider(assetId));
                return history.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(color: orange),
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      error is ApiException
                          ? error.message
                          : 'Couldn\'t load history.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  data: (entries) => entries.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('No history recorded yet.'),
                        )
                      : Column(
                          children: [
                            for (final entry in entries)
                              AssetHistoryTile(entry: entry),
                          ],
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AssetHistoryTile extends StatelessWidget {
  const AssetHistoryTile({super.key, required this.entry});

  final AssetHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.description,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF202625),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            [
              DateFormat.yMMMd().add_jm().format(entry.createdAt.toLocal()),
              if (entry.actorEmail != null) entry.actorEmail!,
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: Color(0xFF59635F)),
          ),
        ],
      ),
    );
  }
}
