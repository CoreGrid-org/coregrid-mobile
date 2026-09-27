import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/auth/me_provider.dart';
import '../../../shared/org_config/org_config_providers.dart';
import '../../../shared/widgets/ui.dart';
import '../../assets/assets_api.dart';
import '../maintenance_providers.dart';
import '../models/maintenance_filter.dart';
import '../widgets/fault_tile.dart';

/// FR-042: every maintenance record the officer can see, filtered by
/// status, priority, type, department, asset, assignee and date range, with
/// sorting and "Load more" pagination — all applied server-side by
/// `GET /api/maintenance`. Lives in the Officer's Faults tab.
class MaintenanceRecordsView extends ConsumerStatefulWidget {
  const MaintenanceRecordsView({super.key, this.assignedToMe = false});

  /// Start with the "Assigned to me" filter on (dashboard "See all").
  final bool assignedToMe;

  @override
  ConsumerState<MaintenanceRecordsView> createState() =>
      _MaintenanceRecordsViewState();
}

class _MaintenanceRecordsViewState
    extends ConsumerState<MaintenanceRecordsView> {
  MaintenanceFilter _filter = const MaintenanceFilter();
  int _pages = 1;
  bool _appliedAssigned = false;

  void _setFilter(MaintenanceFilter filter) => setState(() {
    _filter = filter;
    _pages = 1;
  });

  Future<void> _refresh() async {
    ref.invalidate(maintenancePageProvider);
    await ref.read(maintenancePageProvider((_filter, 1)).future);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).asData?.value;
    if (widget.assignedToMe && !_appliedAssigned && me != null) {
      _appliedAssigned = true;
      _filter = _filter.copyWith(assigneeId: () => me.id);
    }

    final pages = [
      for (var p = 1; p <= _pages; p++)
        ref.watch(maintenancePageProvider((_filter, p))),
    ];
    final first = pages.first;
    final loaded = pages.takeWhile((p) => p.hasValue).map((p) => p.value!);
    final items = [for (final p in loaded) ...p.items];
    final last = pages.last;

    return Column(
      children: [
        _FilterBar(filter: _filter, myId: me?.id, onChanged: _setFilter),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: switch (first) {
              AsyncError(:final error) when !first.hasValue => ErrorView(
                error: error,
                title: 'Couldn\'t load maintenance records',
                onRetry: () => ref.invalidate(maintenancePageProvider),
              ),
              _ when !first.hasValue => const LoadingView(),
              _ when items.isEmpty => MessageView(
                icon: Icons.handyman_outlined,
                title: 'No maintenance records',
                message: _filter.activeCount > 0
                    ? 'Nothing matches these filters.'
                    : 'Nothing has been reported yet.',
                action: _filter.activeCount > 0
                    ? OutlinedButton(
                        onPressed: () =>
                            _setFilter(MaintenanceFilter(sort: _filter.sort)),
                        child: const Text('Clear filters'),
                      )
                    : null,
              ),
              _ => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.pageInsetsFab,
                children: [
                  SectionHeader(
                    '${first.value!.totalCount} '
                    '${first.value!.totalCount == 1 ? 'record' : 'records'}',
                    padding: const EdgeInsets.only(
                      top: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                    ),
                  ),
                  ListCard(children: [for (final r in items) FaultTile(r)]),
                  const SizedBox(height: AppSpacing.md),
                  switch (last) {
                    AsyncError(:final error) => Notice(
                      tone: StatusTone.danger,
                      message: errorMessageFor(error),
                    ),
                    _ when !last.hasValue => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    _ when last.value!.hasMore => OutlinedButton(
                      onPressed: () => setState(() => _pages++),
                      child: const Text('Load more'),
                    ),
                    _ => const SizedBox(),
                  },
                ],
              ),
            },
          ),
        ),
      ],
    );
  }
}

/// Quick filter chips (assigned to me, status) plus a sheet with the rest.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.myId,
    required this.onChanged,
  });

  final MaintenanceFilter filter;
  final String? myId;
  final ValueChanged<MaintenanceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final count = filter.activeCount;
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.sm,
        ),
        children: [
          ActionChip(
            avatar: const Icon(Icons.tune, size: 18),
            label: Text(count == 0 ? 'Filters' : 'Filters ($count)'),
            onPressed: () async {
              final next = await showModalBottomSheet<MaintenanceFilter>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => _FilterSheet(initial: filter),
              );
              if (next != null) onChanged(next);
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          if (myId != null && myId!.isNotEmpty) ...[
            FilterChip(
              label: const Text('Assigned to me'),
              selected: filter.assigneeId == myId,
              onSelected: (on) => onChanged(
                filter.copyWith(assigneeId: () => on ? myId : null),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          for (final s in MaintenanceStatus.values) ...[
            ChoiceChip(
              label: Text(s.label),
              selected: filter.status == s,
              onSelected: (on) =>
                  onChanged(filter.copyWith(status: () => on ? s : null)),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// The full FR-042 filter set. Pops with the new filter on "Apply".
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});

  final MaintenanceFilter initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late MaintenanceFilter _f = widget.initial;
  late final _assetController = TextEditingController(
    text: widget.initial.assetCode ?? '',
  );
  bool _resolving = false;
  String? _assetError;

  @override
  void dispose() {
    _assetController.dispose();
    super.dispose();
  }

  /// Resolves the typed asset code to an id (the API filters by id), then
  /// pops with the filter.
  Future<void> _apply() async {
    final code = _assetController.text.trim();
    var f = _f;
    if (code.isEmpty) {
      f = f.copyWith(asset: () => null);
    } else if (code != f.assetCode) {
      setState(() {
        _resolving = true;
        _assetError = null;
      });
      try {
        final asset = await ref.read(assetsApiProvider).getByCode(code);
        f = f.copyWith(asset: () => (id: asset.id, code: asset.assetCode));
      } catch (error) {
        if (mounted) {
          setState(() {
            _resolving = false;
            _assetError = errorMessageFor(
              error,
              fallback: 'No asset with that code.',
            );
          });
        }
        return;
      }
    }
    if (mounted) Navigator.pop(context, f);
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      initialDateRange: _f.dateFrom != null && _f.dateTo != null
          ? DateTimeRange(start: _f.dateFrom!, end: _f.dateTo!)
          : null,
    );
    if (range != null) {
      setState(
        () => _f = _f.copyWith(
          dateRange: () => (from: range.start, to: range.end),
        ),
      );
    }
  }

  Widget _chips<T>({
    required String title,
    required List<T> values,
    required String Function(T) label,
    required T? selected,
    required void Function(T?) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.sm,
          ),
          child: Text(title, style: context.text.titleSmall),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final v in values)
              ChoiceChip(
                label: Text(label(v)),
                selected: selected == v,
                onSelected: (on) => setState(() => onSelect(on ? v : null)),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final departments = ref.watch(departmentsProvider);
    final range = _f.dateFrom != null && _f.dateTo != null
        ? '${formatDate(_f.dateFrom!)} – ${formatDate(_f.dateTo!)}'
        : 'Any date';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Filter & sort', style: context.text.titleLarge),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _f = MaintenanceFilter(sort: _f.sort);
                    _assetController.clear();
                  }),
                  child: const Text('Reset'),
                ),
              ],
            ),
            _chips<MaintenanceSort>(
              title: 'Sort by',
              values: MaintenanceSort.values,
              label: (s) => s.label,
              selected: _f.sort,
              onSelect: (s) => _f = _f.copyWith(sort: s ?? _f.sort),
            ),
            _chips<MaintenanceStatus>(
              title: 'Status',
              values: MaintenanceStatus.values,
              label: (s) => s.label,
              selected: _f.status,
              onSelect: (s) => _f = _f.copyWith(status: () => s),
            ),
            _chips<MaintenancePriority>(
              title: 'Priority',
              values: MaintenancePriority.values,
              label: (p) => p.label,
              selected: _f.priority,
              onSelect: (p) => _f = _f.copyWith(priority: () => p),
            ),
            _chips<MaintenanceType>(
              title: 'Type',
              values: MaintenanceType.values,
              label: (t) => t.label,
              selected: _f.type,
              onSelect: (t) => _f = _f.copyWith(type: () => t),
            ),
            const SizedBox(height: AppSpacing.lg),
            switch (departments) {
              AsyncData(:final value) => DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _f.departmentId,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  prefixIcon: Icon(Icons.apartment_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  for (final d in value)
                    DropdownMenuItem(value: d.id, child: Text(d.name)),
                ],
                onChanged: (id) => setState(
                  () => _f = _f.copyWith(
                    department: () => id == null
                        ? null
                        : (
                            id: id,
                            name: value.firstWhere((d) => d.id == id).name,
                          ),
                  ),
                ),
              ),
              AsyncError(:final error) => Notice(
                tone: StatusTone.danger,
                message: errorMessageFor(
                  error,
                  fallback: 'Couldn\'t load departments.',
                ),
              ),
              _ => const LinearProgressIndicator(),
            },
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _assetController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Asset code',
                hintText: 'Any asset',
                prefixIcon: const Icon(Icons.qr_code_2),
                errorText: _assetError,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: RecordTile(
                icon: Icons.date_range_outlined,
                title: 'Reported',
                subtitle: range,
                trailing: _f.dateFrom == null
                    ? null
                    : IconButton(
                        tooltip: 'Clear dates',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(
                          () => _f = _f.copyWith(dateRange: () => null),
                        ),
                      ),
                onTap: _pickDates,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SubmitButton(
              label: 'Apply',
              busyLabel: 'Finding asset…',
              busy: _resolving,
              onPressed: _apply,
            ),
          ],
        ),
      ),
    );
  }
}
