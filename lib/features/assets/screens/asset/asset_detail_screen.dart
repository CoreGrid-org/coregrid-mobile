import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/api/api_exception.dart';
import '../../../../shared/widgets/ui.dart';
import '../../assets_providers.dart';
import '../../models/asset/asset_detail.dart';
import '../../widgets/asset/asset_attribute_list.dart';
import '../../widgets/asset/asset_detail_actions.dart';
import '../../widgets/asset/asset_detail_sections.dart';

class AssetDetailScreen extends ConsumerStatefulWidget {
  const AssetDetailScreen({
    super.key,
    required this.assetId,
    this.initialAsset,
  });

  final String assetId;
  final AssetDetail? initialAsset;

  @override
  ConsumerState<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends ConsumerState<AssetDetailScreen> {
  AssetDetail? _displayedAsset;

  @override
  Widget build(BuildContext context) {
    final fetchedAsset = ref.watch(assetDetailProvider(widget.assetId));
    ref.listen<AsyncValue<AssetDetail>>(assetDetailProvider(widget.assetId), (
      _,
      next,
    ) {
      final latest = next.asData?.value;
      if (latest != null && mounted) setState(() => _displayedAsset = latest);
    });
    final asset = _displayedAsset != null
        ? AsyncValue<AssetDetail>.data(_displayedAsset!)
        : widget.initialAsset != null
        ? AsyncValue<AssetDetail>.data(widget.initialAsset!)
        : fetchedAsset;

    return Scaffold(
      appBar: AppBar(title: Text(asset.asData?.value.assetCode ?? 'Asset')),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.refresh(assetDetailProvider(widget.assetId).future),
        child: switch (asset) {
          AsyncData(:final value) => _AssetBody(asset: value),
          AsyncError(:final error) => _AssetError(
            error: error,
            onRetry: () => ref.invalidate(assetDetailProvider(widget.assetId)),
          ),
          _ => const LoadingView(),
        },
      ),
    );
  }
}

class _AssetBody extends StatefulWidget {
  const _AssetBody({required this.asset});

  final AssetDetail asset;

  @override
  State<_AssetBody> createState() => _AssetBodyState();
}

enum _AssetTab { details, attributes, history }

class _AssetBodyState extends State<_AssetBody> {
  _AssetTab _tab = _AssetTab.details;

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final condition =
        asset.condition?.label ??
        (asset.conditionRaw.isEmpty ? 'Unknown' : asset.conditionRaw);
    final subtitle = [
      asset.assetTypeName,
      asset.departmentName,
    ].where((s) => s.isNotEmpty).join(' · ');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.pageInsets,
      children: [
        ClayCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EntityHeader(
                  large: true,
                  icon: Icons.inventory_2_outlined,
                  title: asset.name,
                  subtitle: subtitle,
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    StatusPill(asset.lifecycleStatus.label),
                    StatusPill(
                      'Condition: $condition',
                      tone: StatusTone.of(condition),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AssetDetailActions(asset: asset),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SegmentedButton<_AssetTab>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _AssetTab.details, label: Text('Details')),
            ButtonSegment(
              value: _AssetTab.attributes,
              label: Text('Attributes'),
            ),
            ButtonSegment(value: _AssetTab.history, label: Text('History')),
          ],
          selected: {_tab},
          onSelectionChanged: (s) => setState(() => _tab = s.first),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...switch (_tab) {
          _AssetTab.details => [
            ListCard(
              children: [
                InfoRow(label: 'Asset code', value: asset.assetCode),
                InfoRow(label: 'Department', value: _or(asset.departmentName)),
                InfoRow(label: 'Location', value: _or(asset.locationName)),
                InfoRow(
                  label: 'Acquired',
                  value: formatDate(asset.acquisitionDate),
                ),
                InfoRow(
                  label: 'Acquisition cost',
                  value: formatMoney(asset.acquisitionCost),
                ),
                InfoRow(
                  label: 'Residual value',
                  value: formatMoney(asset.residualValue),
                ),
              ],
            ),
            const SectionHeader('Repair summary'),
            AssetRepairSummary(assetId: asset.id),
          ],
          _AssetTab.attributes => [
            AssetAttributeList(attributes: asset.attributes),
          ],
          _AssetTab.history => [AssetHistorySection(assetId: asset.id)],
        },
      ],
    );
  }

  static String _or(String value) => value.isEmpty ? '—' : value;
}

class _AssetError extends StatelessWidget {
  const _AssetError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;

    final (icon, title, detail) = switch (api) {
      ApiException(isNotFound: true) => (
        Icons.search_off_rounded,
        'Asset not found',
        'No asset with this code exists in your organisation.',
      ),
      ApiException(isNetworkError: true) => (
        Icons.wifi_off_rounded,
        'You\'re offline',
        'Connect to a network and try again — no cached asset data is shown.',
      ),
      ApiException(isUnauthorized: true) => (
        Icons.lock_outline_rounded,
        'Session expired',
        'Please sign out and sign in again.',
      ),
      ApiException(:final message) => (
        Icons.error_outline_rounded,
        'Couldn\'t load this asset',
        message,
      ),
      _ => (
        Icons.error_outline_rounded,
        'Couldn\'t load this asset',
        'Something went wrong. Try again.',
      ),
    };

    return MessageView(
      icon: icon,
      tone: StatusTone.danger,
      title: title,
      message: detail,
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 20),
        label: const Text('Retry'),
      ),
    );
  }
}
