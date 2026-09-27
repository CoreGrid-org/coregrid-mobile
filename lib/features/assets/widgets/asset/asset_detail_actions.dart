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
/// non-disposed assets), Condemn Asset (Officer, active/under maintenance).
/// The backend enforces the same rules (403s).
class AssetDetailActions extends ConsumerWidget {
  const AssetDetailActions({super.key, required this.asset});

  final AssetDetail asset;

  static const dangerRed = Color(0xFFDA1E28);
  static const lightDanger = Color(0xFFFFF1F1);
  static const dangerBorder = Color(0xFFFFB3B8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canVerify = ref.watch(canVerifyAssetsProvider);
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
        extra: {'assetId': asset.id, 'assetCode': asset.assetCode},
      ),
      icon: const Icon(Icons.build_circle_outlined, size: 20),
      label: const Text('Report Fault'),
    );
    final updateCondition = OutlinedButton.icon(
      onPressed: () => _updateCondition(context, ref),
      icon: const Icon(Icons.health_and_safety_outlined, size: 20),
      label: const Text('Update Condition'),
    );
    final condemnAsset = OutlinedButton.icon(
      onPressed: () => _condemnAsset(context, ref),
      style: OutlinedButton.styleFrom(
        foregroundColor: dangerRed,
        backgroundColor: lightDanger,
        side: const BorderSide(color: dangerBorder, width: 1.2),
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
          backgroundColor: dangerRed,
        ),
      );
    }
  }
}
