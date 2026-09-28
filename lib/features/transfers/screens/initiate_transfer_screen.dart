import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/org_config/org_config_models.dart';
import '../../../shared/org_config/org_config_providers.dart';
import '../../../shared/widgets/ui.dart';
import '../../assets/assets_providers.dart';
import '../../assets/models/asset/asset_detail.dart';
import '../../assets/models/asset/asset_search.dart';
import '../../scan/screens/scan_asset_screen.dart';
import '../models/initiate_transfer_request.dart';
import '../transfers_providers.dart';

/// FR-043: creates a transfer request from an authoritative selected asset.
class InitiateTransferScreen extends ConsumerStatefulWidget {
  const InitiateTransferScreen({super.key, this.initialAsset});

  final AssetDetail? initialAsset;

  @override
  ConsumerState<InitiateTransferScreen> createState() =>
      _InitiateTransferScreenState();
}

class _InitiateTransferScreenState
    extends ConsumerState<InitiateTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  AssetDetail? _asset;
  DepartmentDto? _department;
  LocationDto? _location;

  @override
  void initState() {
    super.initState();
    _asset = widget.initialAsset;
  }

  Future<void> _scanAsset() async {
    final asset = await identifyAssetByScan(context);
    if (mounted && asset != null) setState(() => _asset = asset);
  }

  Future<void> _searchAsset() async {
    final asset = await showModalBottomSheet<AssetDetail>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _AssetSearchSheet(),
    );
    if (mounted && asset != null) setState(() => _asset = asset);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _asset == null) {
      return;
    }

    final created = await ref
        .read(initiateTransferControllerProvider.notifier)
        .submit(
          InitiateTransferRequest(
            assetId: _asset!.id,
            toDepartmentId: _department!.id,
            toLocationId: _location!.id,
          ),
        );
    if (!mounted) return;

    final state = ref.read(initiateTransferControllerProvider);
    if (!state.hasError && created != null && created.id.isNotEmpty) {
      context.pushReplacement('/transfers/${created.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(initiateTransferControllerProvider);
    final isSubmitting = submitState.isLoading;
    final departments = ref.watch(departmentsProvider);
    final locations = _department == null
        ? null
        : ref.watch(locationsForDepartmentProvider(_department!.id));

    return Scaffold(
      appBar: AppBar(title: const Text('New transfer request')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              'Choose the asset and where it needs to go.',
              style: context.mutedBody,
            ),
            const SizedBox(height: AppSpacing.lg),
            _AssetSelection(
              asset: _asset,
              enabled: !isSubmitting,
              onScan: _scanAsset,
              onSearch: _searchAsset,
              onClear: () => setState(() => _asset = null),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(
              'Destination',
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
            ),
            switch (departments) {
              AsyncData(:final value) => DropdownButtonFormField<DepartmentDto>(
                isExpanded: true,
                initialValue: _department,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  prefixIcon: Icon(Icons.apartment_outlined),
                ),
                items: [
                  for (final department in value)
                    DropdownMenuItem(
                      value: department,
                      child: Text(department.name),
                    ),
                ],
                onChanged: isSubmitting
                    ? null
                    : (department) => setState(() {
                        _department = department;
                        _location = null;
                      }),
                validator: (_) =>
                    _department == null ? 'Select a department' : null,
              ),
              AsyncError(:final error) => _InlineLoadError(
                message: errorMessageFor(
                  error,
                  fallback: 'Could not load departments.',
                ),
                onRetry: () => ref.invalidate(departmentsProvider),
              ),
              _ => const _FieldLoading(label: 'Loading departments…'),
            },
            const SizedBox(height: AppSpacing.md),
            if (locations != null)
              switch (locations) {
                AsyncData(:final value) =>
                  DropdownButtonFormField<LocationDto>(
                    key: ValueKey(_department!.id),
                    isExpanded: true,
                    initialValue: _location,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                    items: [
                      for (final location in value)
                        DropdownMenuItem(
                          value: location,
                          child: Text(location.name),
                        ),
                    ],
                    onChanged: isSubmitting
                        ? null
                        : (location) =>
                            setState(() => _location = location),
                    validator: (_) =>
                        _location == null ? 'Select a location' : null,
                  ),
                AsyncError(:final error) => _InlineLoadError(
                  message: errorMessageFor(
                    error,
                    fallback: 'Could not load locations.',
                  ),
                  onRetry: () => ref.invalidate(
                    locationsForDepartmentProvider(_department!.id),
                  ),
                ),
                _ => const _FieldLoading(label: 'Loading locations…'),
              }
            else
              const InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                child: Text('Select a department first'),
              ),
            if (submitState.hasError) ...[
              const SizedBox(height: AppSpacing.lg),
              Notice(
                tone: StatusTone.danger,
                title: 'Request could not be submitted',
                message: errorMessageFor(submitState.error!),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: isSubmitting ? null : _submit,
              icon: isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(isSubmitting ? 'Submitting…' : 'Submit request'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetSelection extends StatelessWidget {
  const _AssetSelection({
    required this.asset,
    required this.enabled,
    required this.onScan,
    required this.onSearch,
    required this.onClear,
  });

  final AssetDetail? asset;
  final bool enabled;
  final VoidCallback onScan;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          'Asset',
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
        ),
        if (asset == null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              border: Border.all(color: context.colors.outlineVariant),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Select the asset to move',
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Scan its QR label or find it by code or name.',
                  style: context.mutedSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: enabled ? onScan : null,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: enabled ? onSearch : null,
                        icon: const Icon(Icons.search),
                        label: const Text('Search'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.colors.primaryContainer.withValues(alpha: 0.35),
              border: Border.all(
                color: context.colors.primary.withValues(alpha: 0.35),
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: context.colors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset!.assetCode,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          asset!.name,
                          asset!.departmentName,
                          asset!.locationName,
                        ].where((value) => value.isNotEmpty).join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.mutedSmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: enabled ? onClear : null,
                  tooltip: 'Change asset',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AssetSearchSheet extends ConsumerStatefulWidget {
  const _AssetSearchSheet();

  @override
  ConsumerState<_AssetSearchSheet> createState() => _AssetSearchSheetState();
}

class _AssetSearchSheetState extends ConsumerState<_AssetSearchSheet> {
  final _controller = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(
      assetSearchProvider(AssetSearchQuery(search: _search, pageSize: 30)),
    );

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Find an asset', style: context.text.titleLarge),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search by asset code or name',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value.trim()),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: switch (result) {
              AsyncData(:final value) when value.items.isEmpty =>
                const MessageView(
                  icon: Icons.inventory_2_outlined,
                  title: 'No assets found',
                  message: 'Try a different code or name.',
                ),
              AsyncData(:final value) => ListView.separated(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                itemCount: value.items.length,
                separatorBuilder: (_, _) =>
                    const Divider(indent: 72, height: 1),
                itemBuilder: (context, index) {
                  final asset = value.items[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                      vertical: AppSpacing.xs,
                    ),
                    leading: const IconTile(Icons.inventory_2_outlined),
                    title: Text(
                      asset.assetCode,
                      style: context.text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      [
                        asset.name,
                        asset.departmentName,
                        asset.locationName,
                      ].where((value) => value.isNotEmpty).join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, asset),
                  );
                },
              ),
              AsyncError(:final error) => MessageView(
                icon: Icons.error_outline,
                tone: StatusTone.danger,
                title: 'Could not load assets',
                message: errorMessageFor(error),
              ),
              _ => const LoadingView(),
            },
          ),
        ],
      ),
    );
  }
}

class _FieldLoading extends StatelessWidget {
  const _FieldLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: label),
    child: const LinearProgressIndicator(),
  );
}

class _InlineLoadError extends StatelessWidget {
  const _InlineLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Text(message)),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  );
}
