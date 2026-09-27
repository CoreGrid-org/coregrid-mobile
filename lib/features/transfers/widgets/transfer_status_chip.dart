import 'package:flutter/material.dart';

import '../models/transfer_response.dart';

/// Colour-coded status chip for a [TransferStatus]. Used in the list and
/// detail screens wherever a status badge is needed.
class TransferStatusChip extends StatelessWidget {
  const TransferStatusChip({super.key, required this.status});

  final TransferStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      TransferStatus.requested => (Colors.orange.shade700, Icons.hourglass_top_outlined),
      TransferStatus.approved  => (Colors.blue.shade700,   Icons.thumb_up_outlined),
      TransferStatus.inTransit => (Colors.purple.shade700, Icons.local_shipping_outlined),
      TransferStatus.completed => (Colors.green.shade700,  Icons.check_circle_outline),
      TransferStatus.rejected  => (Colors.red.shade700,    Icons.cancel_outlined),
      TransferStatus.cancelled => (Colors.grey.shade600,   Icons.block_outlined),
      TransferStatus.unknown   => (Colors.grey.shade400,   Icons.help_outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
