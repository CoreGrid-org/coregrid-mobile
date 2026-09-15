import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/api/api_exception.dart';
import '../../assets_providers.dart';
import '../../models/asset/asset_detail.dart';
import '../../widgets/asset/asset_attribute_list.dart';
import '../../widgets/asset/asset_detail_actions.dart';
import '../../widgets/asset/asset_detail_sections.dart';

class AssetDetailScreen extends ConsumerWidget {
  const AssetDetailScreen({super.key, required this.assetId});

  final String assetId;

  static const orange = Color(0xFFFF5A00);
  static const lightOrange = Color(0xFFFFF0E8);
  static const darkText = Color(0xFF202625);
  static const secondaryText = Color(0xFF59635F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = ref.watch(assetDetailProvider(assetId));

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          asset.asData?.value.assetCode ?? 'Asset',
          style: const TextStyle(
            color: darkText,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: darkText),
      ),

      body: RefreshIndicator(
        color: orange,

        onRefresh: () => ref.refresh(assetDetailProvider(assetId).future),

        child: asset.when(
          loading: () => const _CenteredScroll(
            child: CircularProgressIndicator(color: orange),
          ),

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

class _AssetBody extends StatefulWidget {
  const _AssetBody({required this.asset});

  final AssetDetail asset;

  @override
  State<_AssetBody> createState() => _AssetBodyState();
}

class _AssetBodyState extends State<_AssetBody> {
  int _selectedTab = 0;

  static const orange = Color(0xFFFF5A00);
  static const lightOrange = Color(0xFFFFF0E8);
  static const darkText = Color(0xFF202625);
  static const secondaryText = Color(0xFF59635F);

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final condition =
        asset.condition?.label ??
        (asset.conditionRaw.isEmpty ? 'Unknown' : asset.conditionRaw);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: lightOrange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 32,
                color: orange,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 27,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    asset.assetTypeName,
                    style: const TextStyle(
                      fontSize: 15,
                      color: secondaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AssetStatusTag(
              icon: Icons.circle,
              label: asset.lifecycleStatus.label,
            ),
            AssetStatusTag(
              icon: Icons.health_and_safety_outlined,
              label: condition,
            ),
          ],
        ),
        const SizedBox(height: 24),
        AssetDetailActions(asset: asset),
        const SizedBox(height: 24),
        _AssetTabBar(
          selectedIndex: _selectedTab,
          onSelected: (index) => setState(() => _selectedTab = index),
        ),
        const SizedBox(height: 20),
        _selectedContent(asset),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _selectedContent(AssetDetail asset) {
    return switch (_selectedTab) {
      0 => AssetDetailSection(
        title: 'Details',
        icon: Icons.info_outline_rounded,
        child: Column(
          children: [
            AssetDetailRow(label: 'Asset code', value: asset.assetCode),
            AssetDetailRow(label: 'Department', value: asset.departmentName),
            AssetDetailRow(label: 'Location', value: asset.locationName),
            AssetDetailRow(
              label: 'Acquired',
              value: DateFormat.yMMMMd().format(asset.acquisitionDate),
            ),
            AssetDetailRow(
              label: 'Acquisition cost',
              value: _money(asset.acquisitionCost),
            ),
            AssetDetailRow(
              label: 'Residual value',
              value: _money(asset.residualValue),
            ),
          ],
        ),
      ),
      1 => AssetDetailSection(
        title: 'Attributes',
        icon: Icons.tune_rounded,
        child: AssetAttributeList(attributes: asset.attributes),
      ),
      _ => AssetHistorySection(assetId: asset.id),
    };
  }

  static String _money(num value) =>
      NumberFormat.decimalPatternDigits(decimalDigits: 2).format(value);
}

class _AssetTabBar extends StatelessWidget {
  const _AssetTabBar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const orange = Color(0xFFFF5A00);
  static const inactive = Color(0xFF59635F);

  static const tabs = [
    (label: 'Details', icon: Icons.info_outline_rounded),
    (label: 'Attributes', icon: Icons.tune_rounded),
    (label: 'History', icon: Icons.history_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8E9E8))),
      ),
      child: Row(
        children: [
          for (var index = 0; index < tabs.length; index++)
            Expanded(
              child: InkWell(
                onTap: () => onSelected(index),
                child: Container(
                  padding: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selectedIndex == index
                            ? orange
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tabs[index].icon,
                        size: 21,
                        color: selectedIndex == index ? orange : inactive,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          tabs[index].label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selectedIndex == index ? orange : inactive,
                            fontSize: 14,
                            fontWeight: selectedIndex == index
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// ERROR
// ============================================================================

class _AssetError extends StatelessWidget {
  const _AssetError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  static const orange = Color(0xFFFF5A00);
  static const lightOrange = Color(0xFFFFF0E8);
  static const darkText = Color(0xFF202625);
  static const secondaryText = Color(0xFF59635F);

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
        'Connect to a network and try again — '
            'no cached asset data is shown.',
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

    return _CenteredScroll(
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: lightOrange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 30, color: orange),
            ),

            const SizedBox(height: 18),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: darkText,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: secondaryText,
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'Retry',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CENTERED SCROLL
// ============================================================================

class _CenteredScroll extends StatelessWidget {
  const _CenteredScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: child),
            ),
          ),
        );
      },
    );
  }
}
