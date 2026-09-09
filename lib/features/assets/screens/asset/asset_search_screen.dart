import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/api/api_exception.dart';
import '../../assets_providers.dart';
import '../../models/asset/asset_search.dart';

class AssetSearchScreen extends ConsumerStatefulWidget {
  const AssetSearchScreen({super.key});

  @override
  ConsumerState<AssetSearchScreen> createState() => _AssetSearchScreenState();
}

class _AssetSearchScreenState extends ConsumerState<AssetSearchScreen> {
  AssetSearchQuery? _query;
  String _search = '';
  String _department = '';
  String _location = '';
  String _category = '';
  String _assetType = '';
  String _status = '';
  String _condition = '';
  String _sortBy = 'name';
  String _sortOrder = 'asc';

  void _submit() {
    FocusScope.of(context).unfocus();
    setState(() {
      _query = AssetSearchQuery(
        search: _search,
        department: _department,
        location: _location,
        category: _category,
        assetType: _assetType,
        status: _status,
        condition: _condition,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _query == null
        ? null
        : ref.watch(assetSearchProvider(_query!));

    return Scaffold(
      appBar: AppBar(title: const Text('Search Assets')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Find assets by code, name, or custom attribute value.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              textInputAction: TextInputAction.search,
              onChanged: (value) => _search = value,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Code, name, or attribute value',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _selectionRow(
              label: 'Department',
              value: _department,
              options: const ['', 'Operations'],
              onChanged: (value) => setState(() => _department = value!),
            ),
            const SizedBox(height: 12),
            _selectionRow(
              label: 'Location',
              value: _location,
              options: const ['', 'Plant A - Section 3'],
              onChanged: (value) => setState(() => _location = value!),
            ),
            const SizedBox(height: 12),
            _selectionRow(
              label: 'Asset type',
              value: _assetType,
              options: const ['', 'Equipment'],
              onChanged: (value) => setState(() => _assetType = value!),
            ),
            const SizedBox(height: 12),
            _selectionRow(
              label: 'Category',
              value: _category,
              options: const ['', 'Equipment'],
              onChanged: (value) => setState(() => _category = value!),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _selection(
                  label: 'Status',
                  value: _status,
                  options: const ['', 'ACTIVE', 'UNDER_MAINTENANCE', 'DISPOSED'],
                  onChanged: (value) => setState(() => _status = value!),
                ),
                _selection(
                  label: 'Condition',
                  value: _condition,
                  options: const ['', 'NEW', 'GOOD', 'FAIR', 'POOR', 'UNSERVICEABLE'],
                  onChanged: (value) => setState(() => _condition = value!),
                ),
                _selection(
                  label: 'Sort by',
                  value: _sortBy,
                  options: const ['name', 'asset_code', 'status', 'condition', 'location'],
                  onChanged: (value) => setState(() => _sortBy = value!),
                ),
                _selection(
                  label: 'Order',
                  value: _sortOrder,
                  options: const ['asc', 'desc'],
                  onChanged: (value) => setState(() => _sortOrder = value!),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.manage_search),
              label: const Text('Search'),
            ),
            if (results != null) ...[
              const SizedBox(height: 20),
              _SearchResults(
                state: results,
                query: _query!,
                onPageChanged: (page) => setState(
                  () => _query = _query!.copyWith(page: page),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _selectionRow({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return _selection(
      label: label,
      value: value,
      options: options,
      onChanged: onChanged,
      fullWidth: true,
    );
  }

  Widget _selection({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    bool fullWidth = false,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : 165,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final option in options)
            DropdownMenuItem(
              value: option,
              child: Text(option.isEmpty ? 'Any' : option),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
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
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _SearchError(error: error),
      data: (result) {
        if (result.items.isEmpty) return const Text('No assets found.');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${result.totalCount} asset(s) found'),
            const SizedBox(height: 8),
            for (final asset in result.items)
              Card(
                child: ListTile(
                  title: Text(asset.name),
                  subtitle: Text(
                    '${asset.assetCode} · ${asset.assetTypeName}\n'
                    '${asset.departmentName} · ${asset.locationName}',
                  ),
                  isThreeLine: true,
                  trailing: Text(conditionLabel(asset.conditionRaw)),
                  onTap: () => context.push('/assets/${asset.id}'),
                ),
              ),
            if (result.pageCount > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: query.page > 1
                        ? () => onPageChanged(query.page - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous page',
                  ),
                  Text('Page ${query.page} of ${result.pageCount}'),
                  IconButton(
                    onPressed: query.page < result.pageCount
                        ? () => onPageChanged(query.page + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next page',
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;
    final message = api?.isNetworkError == true
        ? 'You\'re offline. Connect to a network and try again.'
        : api?.message ?? 'Something went wrong. Try again.';
    return Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}
