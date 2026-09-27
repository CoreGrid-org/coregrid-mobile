import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/ui.dart';
import '../models/fault_report.dart';

/// One fault report row — used by the Faults tab and the dashboard.
class FaultTile extends StatelessWidget {
  const FaultTile(this.report, {super.key});

  final FaultReport report;

  @override
  Widget build(BuildContext context) {
    final tone = StatusTone.of(report.statusLabel);
    return RecordTile(
      icon: report.isPreventive
          ? Icons.event_repeat_outlined
          : Icons.build_circle_outlined,
      iconTone: tone,
      title: report.assetCode.isNotEmpty
          ? '${report.assetCode} · ${report.description}'
          : report.description,
      subtitle: [
        'Reported ${formatDate(report.reportedAt)}',
        if (report.observedCondition.isNotEmpty)
          humanizeStatus(report.observedCondition),
      ].join(' · '),
      trailing: StatusPill(report.statusLabel, tone: tone),
      onTap: () => context.push('/maintenance/${report.id}', extra: report),
    );
  }
}
