import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The five semantic tones every status in the app maps onto, so a
/// "Completed" task, an "Approved" workflow and a "Resolved" fault all read
/// the same way.
enum StatusTone {
  neutral,
  info,
  success,
  warning,
  danger;

  /// Best-effort tone for a raw API status string (any casing, `_` or
  /// space separated).
  static StatusTone of(String status) {
    return switch (status.trim().toLowerCase().replaceAll('_', ' ')) {
      'completed' ||
      'resolved' ||
      'active' ||
      'approved' ||
      'closed' ||
      'good' ||
      'new' => StatusTone.success,
      'in progress' ||
      'in transit' ||
      'running' ||
      'awaiting approval' ||
      'assigned' => StatusTone.info,
      'pending' ||
      'requested' ||
      'open' ||
      'on hold' ||
      'fair' ||
      'under maintenance' => StatusTone.warning,
      'overdue' ||
      'failed' ||
      'rejected' ||
      'cancelled' ||
      'poor' ||
      'unserviceable' ||
      'critical' ||
      'high' => StatusTone.danger,
      _ => StatusTone.neutral,
    };
  }

  Color foreground(BuildContext context) {
    final c = AppColors.of(context);
    return switch (this) {
      StatusTone.neutral => c.neutral,
      StatusTone.info => c.info,
      StatusTone.success => c.success,
      StatusTone.warning => c.warning,
      StatusTone.danger => c.danger,
    };
  }

  Color background(BuildContext context) {
    final c = AppColors.of(context);
    return switch (this) {
      StatusTone.neutral => c.neutralContainer,
      StatusTone.info => c.infoContainer,
      StatusTone.success => c.successContainer,
      StatusTone.warning => c.warningContainer,
      StatusTone.danger => c.dangerContainer,
    };
  }
}

/// A compact rounded status label. Tone defaults to [StatusTone.of] the
/// label; pass [tone] when the label alone doesn't decide it (e.g. a
/// "Pending" task that is overdue).
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone});

  final String label;
  final StatusTone? tone;

  @override
  Widget build(BuildContext context) {
    final t = tone ?? StatusTone.of(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: t.background(context),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: context.text.labelSmall?.copyWith(
          color: t.foreground(context),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
