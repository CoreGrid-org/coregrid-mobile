import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/ui.dart';
import '../models/transfer_response.dart';
import '../transfers_providers.dart';
import '../widgets/transfer_status_chip.dart';

/// Detail view for a single transfer (FR-043 result + FR-046 entry point).
///
/// Shows the full [TransferResponse] and — when [status] is
/// [TransferStatus.approved] — surfaces a "Confirm Receipt" button that
/// navigates to the scan screen (FR-046).
class TransferDetailScreen extends ConsumerWidget {
  const TransferDetailScreen({super.key, required this.transferId});

  final String transferId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfer = ref.watch(transferDetailProvider(transferId));

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer details')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(transferDetailProvider(transferId).future),
        child: AsyncView(
          value: transfer,
          errorTitle: 'Couldn\'t load this transfer',
          onRetry: () => ref.invalidate(transferDetailProvider(transferId)),
          data: (value) => _TransferDetailBody(transfer: value),
        ),
      ),
    );
  }
}

class _TransferDetailBody extends StatelessWidget {
  const _TransferDetailBody({required this.transfer});

  final TransferResponse transfer;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Text(
                '${transfer.assetCode}: ${transfer.assetName}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            TransferStatusChip(status: transfer.status),
          ],
        ),
        const SizedBox(height: 24),

        // ── Route ────────────────────────────────────────────────────────────
        _Section(title: 'Transfer Route', children: [
          _Row('From', '${transfer.fromDepartmentName ?? '—'} / ${transfer.fromLocationName ?? '—'}'),
          _Row('To',   '${transfer.toDepartmentName ?? '—'} / ${transfer.toLocationName ?? '—'}'),
        ]),
        const SizedBox(height: 16),

        // ── People ───────────────────────────────────────────────────────────
        _Section(title: 'People', children: [
          _Row('Initiated by', transfer.initiatedByUserEmail ?? '—'),
          if (transfer.approvedByUserEmail != null)
            _Row('Approved by', transfer.approvedByUserEmail!),
          if (transfer.confirmedByUserEmail != null)
            _Row('Confirmed by', transfer.confirmedByUserEmail!),
        ]),
        const SizedBox(height: 16),

        // ── Timestamps ───────────────────────────────────────────────────────
        _Section(title: 'Timeline', children: [
          _Row('Requested', _fmt(transfer.requestedAt)),
          if (transfer.approvedAt != null)
            _Row('Approved', _fmt(transfer.approvedAt!)),
          if (transfer.confirmedAt != null)
            _Row('Confirmed', _fmt(transfer.confirmedAt!)),
        ]),

        // ── Rejection reason ─────────────────────────────────────────────────
        if (transfer.rejectionReason != null) ...[
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rejection Reason',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(transfer.rejectionReason!),
                ],
              ),
            ),
          ),
        ],

        // ── Confirm Receipt button (FR-046) ──────────────────────────────────
        if (transfer.status == TransferStatus.approved) ...[
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () =>
                context.push('/transfers/${transfer.id}/confirm-scan'),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Confirm Receipt via Scan'),
          ),
        ],
      ],
    );
  }

  static String _fmt(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(child: Column(children: children)),
        ],
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        title: Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        trailing: Text(value, style: Theme.of(context).textTheme.bodyMedium),
      );
}
