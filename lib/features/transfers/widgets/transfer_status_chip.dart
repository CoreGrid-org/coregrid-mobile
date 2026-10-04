import 'package:flutter/material.dart';

import '../../../shared/widgets/ui.dart';
import '../models/transfer_response.dart';

/// A [StatusPill] for a [TransferStatus], so transfers use the same status
/// colours as every other record in the app.
class TransferStatusChip extends StatelessWidget {
  const TransferStatusChip({super.key, required this.status});

  final TransferStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      TransferStatus.requested => StatusTone.warning,
      TransferStatus.approved || TransferStatus.inTransit => StatusTone.info,
      TransferStatus.completed => StatusTone.success,
      TransferStatus.rejected => StatusTone.danger,
      TransferStatus.cancelled || TransferStatus.unknown => StatusTone.neutral,
    };
    return StatusPill(status.label, tone: tone);
  }
}
