import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/api/api_exception.dart';
import '../../maintenance/maintenance_providers.dart';
import 'dashboard_section.dart';

/// Live section showing the fault reports raised by the current signed-in user
/// (Staff or Inventory Officer), along with their current status and fault description.
class MyFaultReportsSection extends ConsumerStatefulWidget {
  const MyFaultReportsSection({super.key, required this.accent});

  final Color accent;

  @override
  ConsumerState<MyFaultReportsSection> createState() =>
      _MyFaultReportsSectionState();
}

class _MyFaultReportsSectionState extends ConsumerState<MyFaultReportsSection>
    with WidgetsBindingObserver {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidate(myFaultReportsProvider);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(myFaultReportsProvider);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(myFaultReportsProvider);

    return switch (reports) {
      AsyncData(:final value) => DashboardSection(
        title: 'My Fault Reports',
        icon: Icons.assignment_outlined,
        accent: widget.accent,
        emptyLabel: 'You have not reported any faults yet',
        rows: [
          for (final report in value.take(5))
            DashboardRow(
              label: report.assetCode.isNotEmpty
                  ? '${report.assetCode}: ${report.description}'
                  : report.description,
              detail: [
                if (report.observedCondition.isNotEmpty)
                  'Condition: ${report.observedCondition}',
                'Reported ${report.reportedAt.year}-${report.reportedAt.month.toString().padLeft(2, '0')}-${report.reportedAt.day.toString().padLeft(2, '0')}',
              ].join(' · '),
              status: report.statusLabel,
              onTap: () =>
                  context.push('/maintenance/${report.id}', extra: report),
            ),
        ],
      ),
      AsyncError(:final error) => DashboardSection(
        title: 'My Fault Reports',
        icon: Icons.assignment_outlined,
        accent: widget.accent,
        emptyLabel: error is ApiException
            ? error.message
            : 'Could not load fault reports',
        rows: const [],
      ),
      _ => DashboardSection(
        title: 'My Fault Reports',
        icon: Icons.assignment_outlined,
        accent: widget.accent,
        emptyLabel: 'Loading fault reports...',
        rows: const [],
      ),
    };
  }
}
