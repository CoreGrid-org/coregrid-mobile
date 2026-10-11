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
/// Verify is the primary action; Report Fault sits beside a "More" sheet
/// holding the rest, with Condemn set apart as destructive.
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

    // Everything beyond the everyday actions lives behind "More", so the
    // header shows one clear primary action instead of a wall of buttons.
    final more = <_MoreAction>[
      if (canTransfer)
        _MoreAction(
          icon: Icons.local_shipping_outlined,
          label: 'Request Transfer',
          subtitle: 'Move this asset to another location',
          onTap: () => context.push('/transfers/new', extra: asset),
        ),
      if (canUpdateCondition)
        _MoreAction(
          icon: Icons.health_and_safety_outlined,
          label: 'Update Condition',
          subtitle: 'Record the asset\'s current condition',
          onTap: () => _updateCondition(context, ref),
        ),
      if (canCondemn)
        _MoreAction(
          icon: Icons.gavel_outlined,
          label: 'Condemn Asset',
          subtitle: 'Permanently mark as condemned',
          destructive: true,
          onTap: () => _condemnAsset(context, ref),
        ),
    ];

    void reportFault() => context.push('/maintenance/report', extra: asset);
    final secondary = Row(
      children: [
        Expanded(
          child: canVerify
              ? OutlinedButton.icon(
                  onPressed: reportFault,
                  icon: const Icon(Icons.build_circle_outlined, size: 20),
                  label: const Text('Report Fault'),
                )
              : FilledButton.icon(
                  onPressed: reportFault,
                  icon: const Icon(Icons.build_circle_outlined, size: 20),
                  label: const Text('Report Fault'),
                ),
        ),
        if (more.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showMore(context, more),
              icon: const Icon(Icons.more_horiz_rounded, size: 20),
              label: const Text('More'),
            ),
          ),
        ],
      ],
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
        secondary,
      ],
    );
  }

  Future<void> _showMore(BuildContext context, List<_MoreAction> actions) {
    final regular = actions.where((a) => !a.destructive).toList();
    final destructive = actions.where((a) => a.destructive).toList();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final danger = AppColors.of(sheetContext).danger;
        Widget tile(_MoreAction action) {
          final color = action.destructive ? danger : null;
          return ListTile(
            leading: Icon(action.icon, color: color),
            title: Text(action.label, style: TextStyle(color: color)),
            subtitle: Text(action.subtitle),
            onTap: () {
              Navigator.pop(sheetContext);
              action.onTap();
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...regular.map(tile),
              if (regular.isNotEmpty && destructive.isNotEmpty)
                const Divider(height: AppSpacing.lg),
              ...destructive.map(tile),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
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

class _MoreAction {
  const _MoreAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;
}
