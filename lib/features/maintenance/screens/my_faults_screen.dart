import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/ui.dart';
import '../maintenance_providers.dart';
import '../models/fault_report.dart';
import '../widgets/fault_tile.dart';

/// The Faults tab (FR-033 follow-up): every fault the signed-in user has
/// reported, split into active and closed, with a "Report fault" action.
/// Refreshes every 30s while visible, and on resume, so status changes made
/// on the web console show up without a manual pull.
class MyFaultsScreen extends ConsumerStatefulWidget {
  const MyFaultsScreen({super.key});

  @override
  ConsumerState<MyFaultsScreen> createState() => _MyFaultsScreenState();
}

class _MyFaultsScreenState extends ConsumerState<MyFaultsScreen>
    with WidgetsBindingObserver {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      // The tab shell keeps this screen mounted (IndexedStack) — only poll
      // while it's the visible tab and the app is in the foreground.
      final visible = mounted && TickerMode.valuesOf(context).enabled;
      final foreground =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (visible && foreground) ref.invalidate(myFaultReportsProvider);
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
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(myFaultReportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My fault reports')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/maintenance/report'),
        icon: const Icon(Icons.add),
        label: const Text('Report fault'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myFaultReportsProvider.future),
        child: AsyncView(
          value: reports,
          errorTitle: 'Couldn\'t load your fault reports',
          onRetry: () => ref.invalidate(myFaultReportsProvider),
          isEmpty: (value) => value.isEmpty,
          empty: const MessageView(
            icon: Icons.build_circle_outlined,
            title: 'No fault reports yet',
            message:
                'Spotted something broken? Report it and track the repair '
                'here.',
          ),
          data: (value) => _FaultGroups(reports: value),
        ),
      ),
    );
  }
}

class _FaultGroups extends StatelessWidget {
  const _FaultGroups({required this.reports});

  final List<FaultReport> reports;

  @override
  Widget build(BuildContext context) {
    final active = reports.where((r) => r.isOpen || r.isInProgress).toList();
    final closed = reports.where((r) => !r.isOpen && !r.isInProgress).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.pageInsetsFab,
      children: [
        for (final (title, group) in [('Active', active), ('Closed', closed)])
          if (group.isNotEmpty) ...[
            SectionHeader(
              '$title · ${group.length}',
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.sm,
              ),
            ),
            ListCard(children: [for (final r in group) FaultTile(r)]),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}
