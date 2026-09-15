import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets_providers.dart';
import '../../models/asset/asset_detail.dart';
import '../../screens/asset/asset_verification_screen.dart';
import 'condition_update_sheet.dart';

/// The role-and-lifecycle-aware entry points on the asset detail screen
/// (§4.4): Verify, Report Fault, Condition update. An action the user can't
/// take for their role is **not rendered** (IF-02), not merely disabled.
class AssetDetailActions extends ConsumerWidget {
  const AssetDetailActions({super.key, required this.asset});

  final AssetDetail asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canVerify = ref.watch(canVerifyAssetsProvider);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (canVerify)
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AssetVerificationScreen(asset: asset),
              ),
            ),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Verify'),
          ),
        OutlinedButton.icon(
          onPressed: () =>
              _notYetInThisRepo(context, 'features/maintenance (Report Fault)'),
          icon: const Icon(Icons.report_gmailerrorred_outlined),
          label: const Text('Report Fault'),
        ),
        if (asset.allowsConditionUpdate)
          OutlinedButton.icon(
            onPressed: () => _updateCondition(context, ref),
            icon: const Icon(Icons.tune_outlined),
            label: const Text('Update Condition'),
          ),
      ],
    );
  }

  Future<void> _updateCondition(BuildContext context, WidgetRef ref) async {
    final saved = await ConditionUpdateSheet.show(
      context,
      assetId: asset.id,
      current: asset.condition,
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Condition updated.')),
      );
    }
  }

  /// Report Fault remains owned by `features/maintenance/` and is not built in
  /// this feature yet.
  void _notYetInThisRepo(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature isn\'t built yet.')),
    );
  }
}
