import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/transfer_response.dart';
import 'transfer_status_chip.dart';

/// A tappable card summarising one [TransferResponse]. Used in the list
/// screen and in the dashboard "Awaiting My Confirmation" section.
class TransferSummaryCard extends StatelessWidget {
  const TransferSummaryCard({super.key, required this.transfer});

  final TransferResponse transfer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final age = _formatAge(transfer.requestedAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/transfers/${transfer.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${transfer.assetCode}: ${transfer.assetName}',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TransferStatusChip(status: transfer.status),
                ],
              ),
              if (transfer.toDepartmentName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'To: ${transfer.toDepartmentName}'
                  '${transfer.toLocationName != null ? ' — ${transfer.toLocationName}' : ''}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                age,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
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
