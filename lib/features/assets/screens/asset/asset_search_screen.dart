import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/api/api_exception.dart';
import '../../assets_providers.dart';
import '../../models/asset/asset_search.dart';

const _orange = Color(0xFFFF5A00);
const _darkText = Color(0xFF202625);
const _secondaryText = Color(0xFF59635F);
const _fieldFill = Color(0xFFF8F9F8);

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Search Assets',
          style: TextStyle(
            color: _darkText,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: _darkText),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            Text(
              'Find assets by code, name, or custom attribute value.',
              style: const TextStyle(
                fontSize: 16,
                color: _secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              textInputAction: TextInputAction.search,
              onChanged: (value) => _search = value,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Code, name, or attribute value',
                prefixIcon: const Icon(Icons.search, color: _orange, size: 28),
                filled: true,
                fillColor: _fieldFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  borderSide: BorderSide(color: _orange, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
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
                  options: const [
                    '',
                    'ACTIVE',
                    'UNDER_MAINTENANCE',
                    'DISPOSED',
                  ],
                  onChanged: (value) => setState(() => _status = value!),
                ),
                _selection(
                  label: 'Condition',
                  value: _condition,
                  options: const [
                    '',
                    'NEW',
                    'GOOD',
                    'FAIR',
                    'POOR',
                    'UNSERVICEABLE',
                  ],
                  onChanged: (value) => setState(() => _condition = value!),
                ),
                _selection(
                  label: 'Sort by',
                  value: _sortBy,
                  options: const [
                    'name',
                    'asset_code',
                    'status',
                    'condition',
                    'location',
                  ],
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
              style: FilledButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.manage_search, size: 22),
              label: const Text(
                'Search',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            if (results != null) ...[
              const SizedBox(height: 20),
              _SearchResults(
                state: results,
                query: _query!,
                onPageChanged: (page) =>
                    setState(() => _query = _query!.copyWith(page: page)),
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
          filled: true,
          fillColor: _fieldFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: _orange, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 17,
          ),
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
            Text(
              '${result.totalCount} asset(s) found',
              style: const TextStyle(
                color: _secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final asset in result.items)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 0,
                color: _fieldFill,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 6,
                  ),
                  title: Text(
                    asset.name,
                    style: const TextStyle(
                      color: _darkText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${asset.assetCode} · ${asset.assetTypeName}\n'
                    '${asset.departmentName} · ${asset.locationName}',
                    style: const TextStyle(color: _secondaryText),
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    conditionLabel(asset.conditionRaw),
                    style: const TextStyle(
                      color: _orange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
