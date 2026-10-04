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

  static String _place(String? department, String? location) => [
    department,
    location,
  ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  @override
  Widget build(BuildContext context) {
    final from = _place(transfer.fromDepartmentName, transfer.fromLocationName);
    final to = _place(transfer.toDepartmentName, transfer.toLocationName);

    // Shared-kit rows ([InfoRow]) wrap long departments, locations and
    // emails — a ListTile's trailing text overflowed and failed layout.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.pageInsets,
      children: [
        ClayCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: EntityHeader(
              icon: Icons.local_shipping_outlined,
              iconTone: StatusTone.info,
              title: transfer.assetName.isEmpty
                  ? transfer.assetCode
                  : transfer.assetName,
              subtitle: transfer.assetCode,
              trailing: TransferStatusChip(status: transfer.status),
              large: true,
            ),
          ),
        ),
        if (transfer.rejectionReason case final reason?
            when reason.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Notice(tone: StatusTone.danger, title: 'Rejected', message: reason),
        ],
        const SectionHeader('Route'),
        ListCard(
          children: [
            InfoRow(
              icon: Icons.logout_rounded,
              label: 'From',
              value: from.isEmpty ? '—' : from,
            ),
            InfoRow(
              icon: Icons.login_rounded,
              label: 'To',
              value: to.isEmpty ? '—' : to,
            ),
          ],
        ),
        const SectionHeader('People'),
        ListCard(
          children: [
            InfoRow(
              label: 'Requested by',
              value: transfer.initiatedByUserEmail ?? '—',
            ),
            if (transfer.approvedByUserEmail case final email?)
              InfoRow(label: 'Approved by', value: email),
            if (transfer.confirmedByUserEmail case final email?)
              InfoRow(label: 'Received by', value: email),
          ],
        ),
        const SectionHeader('Timeline'),
        ListCard(
          children: [
            InfoRow(
              label: 'Requested',
              value: formatDateTime(transfer.requestedAt),
            ),
            if (transfer.approvedAt case final at?)
              InfoRow(label: 'Approved', value: formatDateTime(at)),
            if (transfer.confirmedAt case final at?)
              InfoRow(label: 'Received', value: formatDateTime(at)),
          ],
        ),
        // FR-046: receipt is confirmed by scanning the delivered asset.
        if (transfer.status == TransferStatus.approved) ...[
          const SizedBox(height: AppSpacing.xl),
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
}
