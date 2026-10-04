import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/ui.dart';
import '../models/transfer_response.dart';
import 'transfer_status_chip.dart';

/// One [TransferResponse] as a [RecordTile] row, for a [ListCard] in the
/// list screen and in the dashboard "Transfers to receive" section.
class TransferSummaryCard extends StatelessWidget {
  const TransferSummaryCard({super.key, required this.transfer});

  final TransferResponse transfer;

  @override
  Widget build(BuildContext context) {
    final destination = [
      transfer.toDepartmentName,
      transfer.toLocationName,
    ].whereType<String>().join(' — ');
    return RecordTile(
      icon: Icons.local_shipping_outlined,
      title: '${transfer.assetCode}: ${transfer.assetName}',
      subtitle: [
        if (destination.isNotEmpty) 'To $destination',
        _formatAge(transfer.requestedAt),
      ].join('\n'),
      trailing: TransferStatusChip(status: transfer.status),
      onTap: () => context.push('/transfers/${transfer.id}'),
    );
  }

  static String _formatAge(DateTime requestedAt) {
    final diff = DateTime.now().difference(requestedAt);
    if (diff.inDays > 0) {
      return 'Requested ${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    if (diff.inHours > 0) {
      return 'Requested ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    return 'Requested just now';
  }
}
