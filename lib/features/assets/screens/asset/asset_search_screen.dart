import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/auth/auth_controller.dart';
import '../../../../shared/auth/auth_state.dart';
import '../../../../shared/auth/me_provider.dart';
import '../../../../shared/widgets/ui.dart';
import '../../assets_providers.dart';
import '../../models/asset/asset_search.dart';

/// Filter state edited in the filter sheet — everything in
/// [AssetSearchQuery] except the free-text search and paging.
class _Filters {
  const _Filters({
    this.department = '',
    this.location = '',
    this.category = '',
    this.assetType = '',
    this.status = '',
    this.condition = '',
    this.sortBy = 'name',
    this.sortOrder = 'asc',
  });

  final String department;
  final String location;
  final String category;
  final String assetType;
  final String status;
  final String condition;
  final String sortBy;
  final String sortOrder;

  int get activeCount => [
    department,
    location,
    category,
    assetType,
    status,
    condition,
  ].where((v) => v.isNotEmpty).length;

  _Filters copyWith({
    String? department,
    String? location,
    String? category,
    String? assetType,
    String? status,
    String? condition,
    String? sortBy,
    String? sortOrder,
  }) => _Filters(
    department: department ?? this.department,
    location: location ?? this.location,
    category: category ?? this.category,
    assetType: assetType ?? this.assetType,
    status: status ?? this.status,
    condition: condition ?? this.condition,
    sortBy: sortBy ?? this.sortBy,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}

/// Asset search (FR-028): free text across code, name and custom attribute
/// values, with department / location / type / category / status /
/// condition filters and sorting tucked into a bottom sheet.
class AssetSearchScreen extends ConsumerStatefulWidget {
  const AssetSearchScreen({super.key, this.initialQuery = ''});

  /// Pre-fills the search box and runs the search on open — set when the
  /// dashboard's "Find an asset" bar hands off a name / partial code.
  final String initialQuery;

  @override
  ConsumerState<AssetSearchScreen> createState() => _AssetSearchScreenState();
}

class _AssetSearchScreenState extends ConsumerState<AssetSearchScreen> {
  AssetSearchQuery? _query;
  _Filters _filters = const _Filters();
  late final _searchController = TextEditingController(
    text: widget.initialQuery,
  );

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery.trim();
    if (initial.isNotEmpty) _query = AssetSearchQuery(search: initial);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    setState(() {
      _query = AssetSearchQuery(
        search: _searchController.text,
        department: _filters.department,
        location: _filters.location,
        category: _filters.category,
        assetType: _filters.assetType,
        status: _filters.status,
        condition: _filters.condition,
        sortBy: _filters.sortBy,
        sortOrder: _filters.sortOrder,
      );
    });
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_Filters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FiltersSheet(initial: _filters),
    );
    if (result == null) return;
    setState(() => _filters = result);
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final results = _query == null
        ? null
        : ref.watch(assetSearchProvider(_query!));
    final active = _filters.activeCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Search assets')),
      body: ListView(
        padding: AppSpacing.pageInsets,
        children: [
          TextField(
            controller: _searchController,
            autofocus: widget.initialQuery.isEmpty,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              hintText: 'Code, name, or attribute value',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openFilters,
                  icon: Badge(
                    isLabelVisible: active > 0,
                    label: Text('$active'),
                    child: const Icon(Icons.tune, size: 20),
                  ),
                  label: Text(active > 0 ? 'Filters ($active)' : 'Filters'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.manage_search, size: 20),
                  label: const Text('Search'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (results == null)
            const Notice(
              message:
                  'Search by asset code, name or any custom attribute value. '
                  'Leave it blank to list everything you can see.',
            )
          else
            _SearchResults(
              state: results,
              query: _query!,
              onPageChanged: (page) =>
                  setState(() => _query = _query!.copyWith(page: page)),
            ),
        ],
      ),
    );
  }
}

class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet({required this.initial});

  final _Filters initial;

  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<_FiltersSheet> {
  late _Filters _f = widget.initial;

  static const _statuses = ['', 'ACTIVE', 'UNDER_MAINTENANCE', 'DISPOSED'];
  static const _conditions = [
    '',
    'NEW',
    'GOOD',
    'FAIR',
    'POOR',
    'UNSERVICEABLE',
  ];
  static const _sorts = {
    'name': 'Name',
    'asset_code': 'Asset code',
    'status': 'Status',
    'condition': 'Condition',
    'location': 'Location',
  };

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isStaff = auth is AuthAuthenticated && auth.role == 'Staff';
    final staffDepartment = isStaff
        ? ref.watch(myWorkplaceProvider).asData?.value?.departmentId
        : null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Filters', style: context.text.titleLarge),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _f = const _Filters()),
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Staff only ever see their own department's assets (the API
              // enforces it), so a department filter would be noise and the
              // location list is narrowed to that department.
              if (!isStaff)
                _optionsField(
                  'Department',
                  '/api/departments',
                  (v) => _f = _f.copyWith(department: v),
                ),
              _optionsField(
                'Location',
                staffDepartment == null
                    ? '/api/locations'
                    : '/api/locations?departmentId=$staffDepartment',
                (v) => _f = _f.copyWith(location: v),
              ),
              _optionsField(
                'Asset type',
                '/api/asset-types',
                (v) => _f = _f.copyWith(assetType: v),
              ),
              _optionsField(
                'Category',
                '/api/asset-categories',
                (v) => _f = _f.copyWith(category: v),
              ),
              Row(
                children: [
                  Expanded(
                    child: _dropdown('Status', _f.status, {
                      for (final s in _statuses)
                        s: s.isEmpty ? 'Any' : humanizeStatus(s),
                    }, (v) => _f = _f.copyWith(status: v)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _dropdown('Condition', _f.condition, {
                      for (final c in _conditions)
                        c: c.isEmpty ? 'Any' : humanizeStatus(c),
                    }, (v) => _f = _f.copyWith(condition: v)),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _dropdown(
                      'Sort by',
                      _f.sortBy,
                      _sorts,
                      (v) => _f = _f.copyWith(sortBy: v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _dropdown('Order', _f.sortOrder, const {
                      'asc': 'Ascending',
                      'desc': 'Descending',
                    }, (v) => _f = _f.copyWith(sortOrder: v)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: () => Navigator.pop(context, _f),
                child: const Text('Apply filters'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    Map<String, String> options,
    void Function(String) apply,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DropdownButtonFormField<String>(
        initialValue: options.containsKey(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final e in options.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) => setState(() => apply(v ?? '')),
      ),
    );
  }

  /// A dropdown whose options come from an org-config endpoint.
  Widget _optionsField(
    String label,
    String resourcePath,
    void Function(String) apply,
  ) {
    final options = ref.watch(assetFilterOptionsProvider(resourcePath));
    return switch (options) {
      AsyncData(:final value) => _dropdown(label, _current(label), {
        '': 'Any',
        for (final o in value) o: o,
      }, apply),
      AsyncError() => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Text(
            'Could not load options',
            style: TextStyle(color: context.colors.error),
          ),
        ),
      ),
      _ => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: const LinearProgressIndicator(),
        ),
      ),
    };
  }

  String _current(String label) => switch (label) {
    'Department' => _f.department,
    'Location' => _f.location,
    'Asset type' => _f.assetType,
    _ => _f.category,
  };
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.state,
    required this.query,
    required this.onPageChanged,
  });

  final AsyncValue<AssetSearchResult> state;
  final AssetSearchQuery query;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      AsyncData(value: final result) when result.items.isEmpty => const Notice(
        icon: Icons.search_off,
        title: 'No assets found',
        message: 'Try a different code or name, or clear some filters.',
      ),
      AsyncData(value: final result) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${result.totalCount} '
            '${result.totalCount == 1 ? 'asset' : 'assets'} found',
            style: context.text.titleSmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClayCard(
            child: Column(
              children: [
                for (var i = 0; i < result.items.length; i++) ...[
                  if (i > 0) const Divider(indent: AppSpacing.lg),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xs,
                    ),
                    leading: const IconTile(Icons.inventory_2_outlined),
                    title: Text(
                      result.items[i].name,
                      style: context.text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${result.items[i].assetCode} · '
                      '${result.items[i].assetTypeName}\n'
                      '${result.items[i].departmentName} · '
                      '${result.items[i].locationName}',
                    ),
                    isThreeLine: true,
                    trailing: StatusPill(
                      conditionLabel(result.items[i].conditionRaw),
                    ),
                    onTap: () => context.push('/assets/${result.items[i].id}'),
                  ),
                ],
              ],
            ),
          ),
          if (result.pageCount > 1)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.outlined(
                    onPressed: query.page > 1
                        ? () => onPageChanged(query.page - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous page',
                  ),
                  Text(
                    'Page ${query.page} of ${result.pageCount}',
                    style: context.text.bodyMedium,
                  ),
                  IconButton.outlined(
                    onPressed: query.page < result.pageCount
                        ? () => onPageChanged(query.page + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next page',
                  ),
                ],
              ),
            ),
        ],
      ),
      AsyncError(:final error) => Notice(
        tone: StatusTone.danger,
        message: errorMessageFor(error),
      ),
      _ => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}
