import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/ui.dart';
import '../assets/models/asset/asset_detail.dart';
import '../scan/screens/scan_asset_screen.dart';
import 'verification_providers.dart';

/// The field procedure (FR-059): walk up to an asset, scan its label, and
/// land on the right verification — the officer's pending campaign task for
/// it (identity already confirmed by the scan), or, when no task covers it,
/// an ad-hoc verification (FR-031) after confirming.
Future<void> scanToVerify(BuildContext context, WidgetRef ref) async {
  final asset = await identifyAssetByScan(context);
  if (asset == null || !context.mounted) return;
  await openVerificationFor(context, ref, asset, scanned: true);
}

/// Opens [asset]'s pending task if the officer has one, else offers ad-hoc
/// verification. [scanned] carries a completed identifying scan through.
Future<void> openVerificationFor(
  BuildContext context,
  WidgetRef ref,
  AssetDetail asset, {
  bool scanned = false,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final tasks = await ref.read(myVerificationTasksProvider.future);
    if (!context.mounted) return;

    final task = tasks
        .where((t) => t.assetId == asset.id && t.isPending)
        .firstOrNull;
    if (task != null) {
      context.push('/verification/${task.id}${scanned ? '?scanned=1' : ''}');
      return;
    }

    final adHoc = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.flag_outlined),
        title: const Text('No task for this asset'),
        content: Text(
          '${asset.assetCode} isn\'t in any of your open campaign tasks. '
          'Record an ad-hoc verification instead?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verify anyway'),
          ),
        ],
      ),
    );
    if (adHoc == true && context.mounted) {
      context.push('/assets/${asset.id}/verify', extra: asset);
    }
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          errorMessageFor(
            error,
            fallback: 'Couldn\'t load your verification tasks. Try again.',
          ),
        ),
      ),
    );
  }
}
