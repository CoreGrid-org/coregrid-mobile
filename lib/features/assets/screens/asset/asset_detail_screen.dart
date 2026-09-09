import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/api/api_exception.dart';
import '../../assets_providers.dart';
import '../../models/asset/asset_detail.dart';
import '../../models/asset/asset_history_entry.dart';
import '../../widgets/asset/asset_attribute_list.dart';
import '../../widgets/asset/asset_detail_actions.dart';

/// FR-020 / §4.4 — the attribute-driven asset detail read view, reached from a
/// scan or a manual code lookup. Route: `/assets/:id`.
///
/// States (IF-01 vocabulary, applied here for consistency): loading, error
/// (not found / offline / other, each retryable), populated.
class AssetDetailScreen extends ConsumerWidget {
  const AssetDetailScreen({super.key, required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = ref.watch(assetDetailProvider(assetId));

    return Scaffold(
      appBar: AppBar(
        title: Text(asset.asData?.value.assetCode ?? 'Asset'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(assetDetailProvider(assetId).future),
        child: asset.when(
          loading: () => const _CenteredScroll(child: CircularProgressIndicator()),
          error: (error, _) => _AssetError(
            error: error,
            onRetry: () => ref.invalidate(assetDetailProvider(assetId)),
          ),
          data: (asset) => _AssetBody(asset: asset),
        ),
      ),
    );
  }
}

class _AssetBody extends StatelessWidget {
  const _AssetBody({required this.asset});

  final AssetDetail asset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(asset.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          asset.assetTypeName,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Tag(
              icon: Icons.circle,
              label: asset.lifecycleStatus.label,
            ),
            _Tag(
              icon: Icons.health_and_safety_outlined,
              label: asset.condition?.label ??
                  (asset.conditionRaw.isEmpty ? 'Unknown' : asset.conditionRaw),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AssetDetailActions(asset: asset),
        const SizedBox(height: 20),
        _Section(
          title: 'Details',
          child: Column(
            children: [
              _DetailRow(label: 'Asset code', value: asset.assetCode),
              _DetailRow(label: 'Department', value: asset.departmentName),
              _DetailRow(label: 'Location', value: asset.locationName),
              _DetailRow(
                label: 'Acquired',
                value: DateFormat.yMMMMd().format(asset.acquisitionDate),
              ),
              _DetailRow(
                label: 'Acquisition cost',
                value: _money(asset.acquisitionCost),
              ),
              _DetailRow(
                label: 'Residual value',
                value: _money(asset.residualValue),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Attributes',
          child: AssetAttributeList(attributes: asset.attributes),
        ),
        const SizedBox(height: 12),
        _HistorySection(assetId: asset.id),
        const SizedBox(height: 32),
      ],
    );
  }

  static String _money(num value) =>
      NumberFormat.decimalPatternDigits(decimalDigits: 2).format(value);
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? '—' : value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        title: Text(
          'History',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        // ExpansionTile builds its children only once expanded, so the history
        // request doesn't fire until the user actually opens the section.
        children: [
          Consumer(
            builder: (context, ref, _) {
              final history = ref.watch(assetHistoryProvider(assetId));
              return history.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
                error: (error, _) => Text(
                  error is ApiException
                      ? error.message
                      : 'Couldn\'t load history.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                data: (entries) => entries.isEmpty
                    ? const Text('No history recorded yet.')
                    : Column(
                        children: [
                          for (final entry in entries)
                            _HistoryTile(entry: entry),
                        ],
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final AssetHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text(
            [
              DateFormat.yMMMd().add_jm().format(entry.createdAt.toLocal()),
              if (entry.actorEmail != null) entry.actorEmail,
            ].join(' · '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetError extends StatelessWidget {
  const _AssetError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error : null;

    final (icon, title, detail) = switch (api) {
      ApiException(isNotFound: true) => (
        Icons.search_off_outlined,
        'Asset not found',
        'No asset with this code exists in your organisation.',
      ),
      ApiException(isNetworkError: true) => (
        Icons.wifi_off_outlined,
        'You\'re offline',
        'Connect to a network and try again — no cached asset data is shown.',
      ),
      ApiException(isUnauthorized: true) => (
        Icons.lock_outline,
        'Session expired',
        'Please sign out and sign in again.',
      ),
      ApiException(:final message) => (
        Icons.error_outline,
        'Couldn\'t load this asset',
        message,
      ),
      _ => (
        Icons.error_outline,
        'Couldn\'t load this asset',
        'Something went wrong. Try again.',
      ),
    };

    return _CenteredScroll(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Keeps content centred but still scrollable, so [RefreshIndicator] works in
/// the loading and error states too.
class _CenteredScroll extends StatelessWidget {
  const _CenteredScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
