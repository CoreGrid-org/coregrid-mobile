import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/ui.dart';
import '../../assets_providers.dart';
import '../../models/asset/asset_detail.dart';
import '../../../transfers/screens/condemn_asset_sheet.dart';
import '../../../transfers/transfers_providers.dart';
import '../../../verification/verify_flow.dart';
import 'condition_update_sheet.dart';

/// The role-and-lifecycle-aware entry points on the asset detail screen:
/// Verify (Officer), Report Fault (everyone), Update Condition (Officer,
/// non-disposed assets), Request Transfer (Officer, ACTIVE assets — FR-043),
/// Condemn Asset (Officer, active/under maintenance — FR-049).
/// The backend enforces the same rules (403/422s).
class AssetDetailActions extends ConsumerWidget {
  const AssetDetailActions({super.key, required this.asset});

  final AssetDetail asset;

    @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canVerify = ref.watch(canVerifyAssetsProvider);
    // Same role as verification (RequestTransfer: Officer/Admin), and only
    // an ACTIVE asset can be transferred.
    final canTransfer =
        canVerify && asset.lifecycleStatus == AssetLifecycleStatus.active;
    final canUpdateCondition =
        ref.watch(canUpdateAssetConditionProvider) &&
        asset.allowsConditionUpdate;
    final canCondemn =
        ref.watch(canCondemnAssetProvider) &&
        (asset.lifecycleStatus == AssetLifecycleStatus.active ||
            asset.lifecycleStatus == AssetLifecycleStatus.underMaintenance);

    final reportFault = OutlinedButton.icon(
      onPressed: () => context.push(
        '/maintenance/report',
        extra: asset,
      ),
      icon: const Icon(Icons.build_circle_outlined, size: 20),
      label: const Text('Report Fault'),
    );
    final updateCondition = OutlinedButton.icon(
      onPressed: () => _updateCondition(context, ref),
      icon: const Icon(Icons.health_and_safety_outlined, size: 20),
      label: const Text('Update Condition'),
    );
    final statusColors = AppColors.of(context);
    final condemnAsset = OutlinedButton.icon(
      onPressed: () => _condemnAsset(context, ref),
      style: OutlinedButton.styleFrom(
        foregroundColor: statusColors.danger,
        backgroundColor: statusColors.dangerContainer,
        side: BorderSide(
          color: statusColors.danger.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      icon: const Icon(Icons.gavel_outlined, size: 20),
      label: const Text('Condemn Asset'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canVerify) ...[
          FilledButton.icon(
            onPressed: () => openVerificationFor(context, ref, asset),
            icon: const Icon(Icons.fact_check_outlined, size: 20),
            label: const Text('Verify'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (canTransfer) ...[
          OutlinedButton.icon(
            onPressed: () => context.push('/transfers/new', extra: asset),
            icon: const Icon(Icons.local_shipping_outlined, size: 20),
            label: const Text('Request Transfer'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (canUpdateCondition)
          Row(
            children: [
              Expanded(child: reportFault),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: updateCondition),
            ],
          )
        else
          reportFault,
        if (canCondemn) ...[
          const SizedBox(height: AppSpacing.md),
          condemnAsset,
        ],
      ],
    );
  }

  // ========================================================================
  // UPDATE CONDITION
  // ========================================================================

  Future<void> _updateCondition(BuildContext context, WidgetRef ref) async {
    final saved = await ConditionUpdateSheet.show(
      context,
      assetId: asset.id,
      current: asset.condition,
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Condition updated.')));
    }
  }

  // ========================================================================
  // CONDEMN ASSET (FR-049)
  // ========================================================================

  Future<void> _condemnAsset(BuildContext context, WidgetRef ref) async {
    final condemned = await CondemnAssetSheet.show(context, asset: asset);

    if (condemned == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Asset ${asset.assetCode} has been condemned.'),
          backgroundColor: AppColors.of(context).danger,
        ),
      );
    }
  }
}
