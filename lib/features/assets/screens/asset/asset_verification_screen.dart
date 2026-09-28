import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/ui.dart';
import '../../../verification/models/verification_task.dart';
import '../../../verification/verification_providers.dart';
import '../../../verification/widgets/verification_form.dart';
import '../../assets_api.dart';
import '../../assets_providers.dart';
import '../../models/asset/asset_condition.dart';
import '../../models/asset/asset_detail.dart';
import '../../models/asset/asset_verification.dart';

/// Ad-hoc physical verification (FR-031) — for an asset the officer is at
/// but has no campaign task for. Same assertion form as task-bound
/// verification ([VerificationForm]); submits to
/// `POST /api/assets/{id}/verify`, which runs the same FR-060 comparison.
/// Route: `/assets/:id/verify` (Officer only).
class AssetVerificationScreen extends ConsumerStatefulWidget {
  const AssetVerificationScreen({
    super.key,
    required this.assetId,
    this.initialAsset,
  });

  final String assetId;
  final AssetDetail? initialAsset;

  @override
  ConsumerState<AssetVerificationScreen> createState() =>
      _AssetVerificationScreenState();
}

class _AssetVerificationScreenState
    extends ConsumerState<AssetVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _present = true;
  String? _locationId;
  ObservedCondition? _condition;
  bool _submitting = false;
  AssetVerificationResult? _result;
  Object? _error;

  Future<void> _submit(AssetDetail asset) async {
    if (_present && !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
      _result = null;
    });
    try {
      // The ad-hoc endpoint always wants a location; for "not found" send
      // the registered one (the server stops at Missing anyway).
      final locations = await ref.read(verificationLocationsProvider.future);
      final locationId =
          (_present ? _locationId : null) ??
          locations.where((l) => l.name == asset.locationName).firstOrNull?.id;
      if (locationId == null) {
        throw StateError('Select a valid observed location.');
      }
      final result = await ref
          .read(assetsApiProvider)
          .verifyAsset(
            assetId: asset.id,
            request: AssetVerificationRequest(
              present: _present,
              locationId: locationId,
              condition:
                  AssetCondition.tryParse(_condition?.apiValue) ??
                  asset.condition ??
                  AssetCondition.good,
            ),
          );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.initialAsset != null
        ? AsyncData<AssetDetail>(widget.initialAsset!)
        : ref.watch(assetDetailProvider(widget.assetId));

    return Scaffold(
      appBar: AppBar(title: const Text('Verify asset')),
      body: AsyncView(
        value: asset,
        errorTitle: 'Couldn\'t load this asset',
        onRetry: () => ref.invalidate(assetDetailProvider(widget.assetId)),
        data: _body,
      ),
    );
  }

  Widget _body(AssetDetail asset) {
    // Pre-select what the register says, so a match is two taps.
    _condition ??= ObservedCondition.tryParse(asset.conditionRaw);
    final result = _result;

    return SingleChildScrollView(
      padding: AppSpacing.pageInsets,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: EntityHeader(
                  large: true,
                  icon: Icons.inventory_2_outlined,
                  title: asset.name,
                  subtitle: '${asset.assetCode} · ${asset.locationName}',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Notice(
              message:
                  'No campaign task covers this asset, so this is recorded as '
                  'an ad-hoc verification.',
            ),
            const SectionHeader('Your observation'),
            VerificationForm(
              enabled: !_submitting && result == null,
              present: _present,
              onPresentChanged: (v) => setState(() => _present = v),
              locationId: _locationId,
              onLocationChanged: (v) => setState(() => _locationId = v),
              condition: _condition,
              onConditionChanged: (v) => setState(() => _condition = v),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: AppSpacing.md),
              Notice(
                tone: StatusTone.danger,
                title: 'Verification failed',
                message: error is StateError
                    ? error.message
                    : errorMessageFor(
                        error,
                        fallback: 'Couldn\'t submit verification. Try again.',
                      ),
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: AppSpacing.md),
              Notice(
                tone: result.discrepancyRaised
                    ? StatusTone.warning
                    : StatusTone.success,
                title: result.discrepancyRaised
                    ? 'Discrepancy raised'
                    : 'Asset verified',
                message:
                    result.message ??
                    (result.discrepancyRaised
                        ? 'The submitted values differ from the asset record.'
                        : 'The asset matches the recorded details.'),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.xl),
              SubmitButton(
                label: 'Submit verification',
                busyLabel: 'Submitting…',
                icon: Icons.fact_check_outlined,
                busy: _submitting,
                onPressed: () => _submit(asset),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
