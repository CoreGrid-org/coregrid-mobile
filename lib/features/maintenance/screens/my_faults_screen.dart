import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/ui.dart';
import '../maintenance_providers.dart';
import '../models/fault_report.dart';
import '../widgets/fault_tile.dart';
import 'maintenance_records_view.dart';

/// The Faults tab (FR-033 follow-up): every fault the signed-in user has
/// reported, split into active and closed, with a "Report fault" action.
/// Refreshes every 30s while visible, and on resume, so status changes made
/// on the web console show up without a manual pull.
///
/// Officers get a second view, "All records" — the FR-042 maintenance list
/// ([MaintenanceRecordsView]). `/faults?view=all` opens it, and
/// `?view=assigned` opens it filtered to the officer's own assignments.
class MyFaultsScreen extends ConsumerStatefulWidget {
  const MyFaultsScreen({super.key, this.view});

  /// `all` / `assigned` (Officer only); anything else shows "My reports".
  final String? view;

  @override
  ConsumerState<MyFaultsScreen> createState() => _MyFaultsScreenState();
}

class _MyFaultsScreenState extends ConsumerState<MyFaultsScreen>
    with WidgetsBindingObserver {
  Timer? _poll;
  late bool _showAll = widget.view == 'all' || widget.view == 'assigned';

  @override
  void didUpdateWidget(MyFaultsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.view != oldWidget.view) {
      _showAll = widget.view == 'all' || widget.view == 'assigned';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      // The tab shell keeps this screen mounted (IndexedStack) — only poll
      // while it's the visible tab and the app is in the foreground.
      final visible =
          mounted && !_showAll && TickerMode.valuesOf(context).enabled;
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
    final canManage = ref.watch(canManageMaintenanceProvider);
    final showAll = canManage && _showAll;

    return Scaffold(
      appBar: AppBar(
        title: Text(canManage ? 'Maintenance' : 'My fault reports'),
        bottom: canManage
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    0,
                    AppSpacing.page,
                    AppSpacing.sm,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('My reports')),
                        ButtonSegment(value: true, label: Text('All records')),
                      ],
                      selected: {showAll},
                      onSelectionChanged: (v) =>
                          setState(() => _showAll = v.first),
                    ),
                  ),
                ),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/maintenance/report'),
        icon: const Icon(Icons.add),
        label: const Text('Report fault'),
      ),
      body: showAll
          ? MaintenanceRecordsView(
              key: ValueKey(widget.view),
              assignedToMe: widget.view == 'assigned',
            )
          : _myReports(),
    );
  }

  Widget _myReports() {
    final reports = ref.watch(myFaultReportsProvider);
    return RefreshIndicator(
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
