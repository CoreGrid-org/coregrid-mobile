import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/ui.dart';
import '../assets/models/asset/asset_detail.dart';
import '../scan/screens/scan_asset_screen.dart';
import 'models/campaign_scope_assets.dart';
import 'models/verification_campaign.dart';
import 'models/verification_task.dart';
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

/// Scan straight from a task row: when the label matches [task]'s asset,
/// open the task with its identity already confirmed; otherwise say which
/// asset was scanned instead.
Future<void> scanTaskAsset(BuildContext context, VerificationTask task) async {
  final asset = await identifyAssetByScan(context);
  if (asset == null || !context.mounted) return;
  if (asset.id == task.assetId) {
    context.push('/verification/${task.id}?scanned=1');
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'That label is ${asset.assetCode} (${asset.name}), not '
        '${task.assetCode}. Find the right asset and scan again.',
      ),
    ),
  );
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

/// What a label scanned from inside a campaign turned out to be, relative to
/// that campaign and the officer's own task list.
sealed class CampaignScanResult {
  const CampaignScanResult();
}

/// On the officer's list for this campaign and still to verify.
class CampaignScanToVerify extends CampaignScanResult {
  const CampaignScanToVerify(this.task);
  final VerificationTask task;
}

/// On the officer's list for this campaign, already verified.
class CampaignScanAlreadyVerified extends CampaignScanResult {
  const CampaignScanAlreadyVerified(this.task);
  final VerificationTask task;
}

/// Not in this campaign, but the officer has a pending task for it in
/// another one.
class CampaignScanOtherCampaign extends CampaignScanResult {
  const CampaignScanOtherCampaign(this.task);
  final VerificationTask task;
}

/// The kind of asset this campaign covers, but not on the officer's list —
/// another officer's task, or registered after the campaign started.
class CampaignScanNotAssigned extends CampaignScanResult {
  const CampaignScanNotAssigned();
}

/// Outside the campaign's scope entirely (wrong type, department or
/// location).
class CampaignScanOutOfScope extends CampaignScanResult {
  const CampaignScanOutOfScope();
}

/// Checks a scanned [asset] against [campaign]: the officer's [myTasks]
/// decide whether it's theirs to verify; [scopeAssets] (null if it couldn't
/// be loaded) decides whether it belongs to the campaign at all. The server
/// still enforces assignment on submit — this is for immediate guidance.
CampaignScanResult classifyCampaignScan({
  required VerificationCampaign campaign,
  required AssetDetail asset,
  required List<VerificationTask> myTasks,
  CampaignScopeAssets? scopeAssets,
}) {
  final forAsset = myTasks.where((t) => t.assetId == asset.id).toList();
  final here = forAsset.where((t) => t.campaignId == campaign.id);

  final pendingHere = here.where((t) => t.isPending).firstOrNull;
  if (pendingHere != null) return CampaignScanToVerify(pendingHere);

  final doneHere = here.firstOrNull;
  if (doneHere != null) return CampaignScanAlreadyVerified(doneHere);

  final elsewhere = forAsset.where((t) => t.isPending).firstOrNull;
  if (elsewhere != null) return CampaignScanOtherCampaign(elsewhere);

  final inScope = switch (scopeAssets) {
    final s? when s.contains(asset.id) => true,
    final s? when s.complete => false,
    _ => campaign.scopeMatchesByName(
      assetTypeName: asset.assetTypeName,
      departmentName: asset.departmentName,
      locationName: asset.locationName,
    ),
  };
  return inScope
      ? const CampaignScanNotAssigned()
      : const CampaignScanOutOfScope();
}

/// "Scan to verify" from inside a campaign: the scan is checked against
/// that campaign, so the officer is told straight away when a label isn't
/// one they should be verifying here — and why — instead of silently
/// landing on an unrelated task or an ad-hoc verification.
Future<void> scanForCampaign(
  BuildContext context,
  WidgetRef ref,
  VerificationCampaign campaign,
) async {
  final asset = await identifyAssetByScan(context);
  if (asset == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final List<VerificationTask> myTasks;
  try {
    myTasks = await ref.read(myVerificationTasksProvider.future);
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
    return;
  }
  CampaignScopeAssets? scopeAssets;
  try {
    scopeAssets = await ref.read(
      campaignScopeAssetsProvider(campaign.id).future,
    );
  } catch (_) {
    // Fall back to the by-name scope check.
  }
  if (!context.mounted) return;

  final result = classifyCampaignScan(
    campaign: campaign,
    asset: asset,
    myTasks: myTasks,
    scopeAssets: scopeAssets,
  );
  if (result case CampaignScanToVerify(:final task)) {
    context.push('/verification/${task.id}?scanned=1');
    return;
  }

  final what =
      '${asset.assetCode} (${asset.name}) — ${asset.assetTypeName}, '
      '${asset.locationName}';
  final (icon, title, message, alternative) = switch (result) {
    // CampaignScanToVerify already returned above.
    CampaignScanToVerify(:final task) ||
    CampaignScanAlreadyVerified(:final task) => (
      Icons.check_circle_outline,
      'Already verified',
      '$what was verified on '
          '${formatDate(task.completedAt ?? task.dueDate)}. '
          'Nothing more to do — move on to the next asset.',
      null,
    ),
    CampaignScanOtherCampaign(:final task) => (
      Icons.swap_horiz,
      'Not in this campaign',
      '$what isn\'t part of ${campaign.name}, but it is on your list '
          'for ${task.campaignName}.',
      (_CampaignScanAction.openTask, 'Open that task'),
    ),
    CampaignScanNotAssigned() => (
      Icons.person_off_outlined,
      'Not on your list',
      '$what fits this campaign but isn\'t assigned to you — another '
          'officer may be verifying it, or it was registered after the '
          'campaign started.',
      (_CampaignScanAction.adHoc, 'Verify ad hoc'),
    ),
    CampaignScanOutOfScope() => (
      Icons.block,
      'Not part of this campaign',
      'You scanned $what. This campaign is checking: '
          '${campaign.scopeSummary}.',
      (_CampaignScanAction.adHoc, 'Verify ad hoc'),
    ),
  };
  final action = await _showScanOutcome(
    context,
    icon: icon,
    title: title,
    message: message,
    alternative: alternative,
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case _CampaignScanAction.scanNext:
      await scanForCampaign(context, ref, campaign);
    case _CampaignScanAction.openTask:
      if (result case CampaignScanOtherCampaign(:final task)) {
        context.push('/verification/${task.id}?scanned=1');
      }
    case _CampaignScanAction.adHoc:
      context.push('/assets/${asset.id}/verify', extra: asset);
  }
}

enum _CampaignScanAction { scanNext, openTask, adHoc }

/// Explains a scan that didn't land on one of the officer's open tasks in
/// the campaign. "Scan next" is the main action — keep walking the list.
Future<_CampaignScanAction?> _showScanOutcome(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  (_CampaignScanAction, String)? alternative,
}) {
  return showDialog<_CampaignScanAction>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(icon),
      title: Text(title),
      content: Text(message),
      actions: [
        if (alternative != null)
          TextButton(
            onPressed: () => Navigator.pop(context, alternative.$1),
            child: Text(alternative.$2),
          )
        else
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _CampaignScanAction.scanNext),
          child: const Text('Scan next'),
        ),
      ],
    ),
  );
}
