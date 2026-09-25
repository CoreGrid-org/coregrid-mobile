import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/api/api_exception.dart';
import '../../assets_providers.dart';
import '../../models/asset/asset_detail.dart';
import '../../../verification/verification_providers.dart';
import 'condition_update_sheet.dart';

/// The role-and-lifecycle-aware entry points on the asset detail screen.
///
/// Verify, Report Fault and Condition Update follow the same
/// orange visual language used throughout the Asset screens.
class AssetDetailActions extends ConsumerWidget {
  const AssetDetailActions({super.key, required this.asset});

  final AssetDetail asset;

  static const orange = Color(0xFFFF5A00);
  static const lightOrange = Color(0xFFFFF0E8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canVerify = ref.watch(canVerifyAssetsProvider);
    final canUpdateCondition = ref.watch(canUpdateAssetConditionProvider);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (canVerify) ...[
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: () => _openVerification(context, ref),
              style: FilledButton.styleFrom(
                backgroundColor: orange,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.fact_check_outlined, size: 22),
              label: const Text(
                'Verify',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
        SizedBox(
          height: 54,
          child: OutlinedButton.icon(
            onPressed: () => _notYetInThisRepo(
              context,
              'features/maintenance (Report Fault)',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: orange,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              side: const BorderSide(color: orange, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.report_gmailerrorred_outlined, size: 22),
            label: const Text(
              'Report Fault',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (canUpdateCondition && asset.allowsConditionUpdate) ...[
          const SizedBox(width: 8),
          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () => _updateCondition(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: orange,
                backgroundColor: lightOrange,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                side: const BorderSide(color: Color(0xFFFFD5C2), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.tune_rounded, size: 22),
              label: const Text(
                'Update Condition',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openVerification(BuildContext context, WidgetRef ref) async {
    try {
      final tasks = await ref.read(myVerificationTasksProvider.future);
      final task = tasks
          .where((item) => item.assetId == asset.id && item.isPending)
          .firstOrNull;

      if (!context.mounted) return;
      if (task == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: const Text(
              'This asset has no pending verification task assigned to you.',
            ),
            action: SnackBarAction(
              label: 'View tasks',
              onPressed: () => context.push('/verification'),
            ),
          ),
        );
        return;
      }

      context.push('/verification/${task.id}');
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Couldn\'t load the verification task. Try again.',
          ),
        ),
      );
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Condition updated.'),
          backgroundColor: orange,
        ),
      );
    }
  }

  // ========================================================================
  // REPORT FAULT
  // ========================================================================

  /// Report Fault remains owned by
  /// `features/maintenance/` and is not built in this feature yet.
  void _notYetInThisRepo(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature isn\'t built yet.'),
        backgroundColor: orange,
      ),
    );
  }
}
