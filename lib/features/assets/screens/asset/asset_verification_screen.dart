import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/api/api_exception.dart';
import '../../assets_api.dart';
import '../../models/asset/asset_condition.dart';
import '../../models/asset/asset_detail.dart';
import '../../models/asset/asset_verification.dart';
import '../../../verification/models/verification_location.dart';
import '../../../verification/verification_providers.dart';

class AssetVerificationScreen extends ConsumerStatefulWidget {
  const AssetVerificationScreen({super.key, required this.asset});

  final AssetDetail asset;

  @override
  ConsumerState<AssetVerificationScreen> createState() =>
      _AssetVerificationScreenState();
}

class _AssetVerificationScreenState
    extends ConsumerState<AssetVerificationScreen> {
  static const orange = Color(0xFFFF5A00);
  static const lightOrange = Color(0xFFFFF0E8);
  static const darkText = Color(0xFF202625);
  static const secondaryText = Color(0xFF59635F);
  static const fieldFill = Color(0xFFF8F9F8);

  final _formKey = GlobalKey<FormState>();
  String? _locationId;
  late AssetCondition _condition;
  bool _present = true;
  bool _submitting = false;
  AssetVerificationResult? _result;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _condition = widget.asset.condition ?? AssetCondition.good;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final api = ref.read(assetsApiProvider);
    if (api is! VerifiableAssetsApi) {
      setState(() => _error = StateError('Verification is not available.'));
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _result = null;
    });
    try {
      final locations = await ref.read(verificationLocationsProvider.future);
      final locationId = _locationId ??
          locations
              .where((location) => location.name == widget.asset.locationName)
              .firstOrNull
              ?.id;
      if (locationId == null) {
        throw StateError('Select a valid observed location.');
      }
      final result = await (api as VerifiableAssetsApi).verifyAsset(
        assetId: widget.asset.id,
        request: AssetVerificationRequest(
          present: _present,
          locationId: locationId,
          condition: _condition,
        ),
      );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: fieldFill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: orange, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
  );

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final locations = ref.watch(verificationLocationsProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Verify Asset',
          style: TextStyle(
            color: darkText,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: darkText),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: lightOrange,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      color: orange,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.asset.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: darkText,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.asset.assetCode,
                          style: const TextStyle(
                            color: secondaryText,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Card(
              elevation: 0,
              color: fieldFill,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: SwitchListTile(
                title: const Text('Asset is present'),
                subtitle: const Text(
                  'Confirm the physical asset is here.',
                  style: TextStyle(color: secondaryText),
                ),
                value: _present,
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _present = value),
                activeTrackColor: orange,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
              ),
            ),
            const SizedBox(height: 12),
            locations.when(
              loading: () => InputDecorator(
                decoration: _fieldDecoration('Observed location'),
                child: const SizedBox(
                  height: 20,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
              error: (error, _) => InputDecorator(
                decoration: _fieldDecoration('Observed location'),
                child: Text(
                  'Could not load locations',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              data: (values) {
                final currentLocation = values
                    .where((location) => location.name == widget.asset.locationName)
                    .firstOrNull;
                final selectedId = _locationId ?? currentLocation?.id;
                return DropdownButtonFormField<String>(
                  initialValue: selectedId,
                  isExpanded: true,
                  decoration: _fieldDecoration('Observed location'),
                  hint: const Text('Select observed location'),
                  items: [
                    for (final VerificationLocation location in values)
                      DropdownMenuItem(
                        value: location.id,
                        child: Text(location.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Select the observed location'
                      : null,
                  onChanged: _submitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _locationId = value);
                          }
                        },
                );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AssetCondition>(
              initialValue: _condition,
              isExpanded: true,
              decoration: _fieldDecoration('Observed condition'),
              items: [
                for (final condition in AssetCondition.values)
                  DropdownMenuItem(
                    value: condition,
                    child: Text(condition.label),
                  ),
              ],
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value != null) setState(() => _condition = value);
                    },
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: Text(
                  _submitting ? 'Submitting…' : 'Submit verification',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _VerificationMessage(
                title: 'Verification failed',
                message: _error is ApiException
                    ? (_error as ApiException).message
                    : 'Couldn\'t submit verification. Try again.',
                color: Theme.of(context).colorScheme.error,
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 16),
              _VerificationMessage(
                title: result.discrepancyRaised
                    ? 'Discrepancy raised'
                    : 'Asset verified',
                message:
                    result.message ??
                    (result.discrepancyRaised
                        ? 'The submitted values differ from the asset record.'
                        : 'The asset matches the recorded details.'),
                color: result.discrepancyRaised
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerificationMessage extends StatelessWidget {
  const _VerificationMessage({
    required this.title,
    required this.message,
    required this.color,
  });

  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.10),
      child: ListTile(
        leading: Icon(Icons.info_outline, color: color),
        title: Text(title),
        subtitle: Text(message),
      ),
    );
  }
}
