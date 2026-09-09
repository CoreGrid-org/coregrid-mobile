import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/api/api_exception.dart';
import '../../assets_api.dart';
import '../../models/asset/asset_condition.dart';
import '../../models/asset/asset_detail.dart';
import '../../models/asset/asset_verification.dart';

class AssetVerificationScreen extends ConsumerStatefulWidget {
  const AssetVerificationScreen({super.key, required this.asset});

  final AssetDetail asset;

  @override
  ConsumerState<AssetVerificationScreen> createState() =>
      _AssetVerificationScreenState();
}

class _AssetVerificationScreenState
    extends ConsumerState<AssetVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _locationController;
  late AssetCondition _condition;
  bool _present = true;
  bool _submitting = false;
  AssetVerificationResult? _result;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(text: widget.asset.locationName);
    _condition = widget.asset.condition ?? AssetCondition.good;
  }

  @override
  void dispose() {
    _locationController.dispose();
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
      final result = await (api as VerifiableAssetsApi).verifyAsset(
        assetId: widget.asset.id,
        request: AssetVerificationRequest(
          present: _present,
          location: _locationController.text,
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

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Asset')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.asset.name, style: Theme.of(context).textTheme.headlineSmall),
            Text(widget.asset.assetCode),
            const SizedBox(height: 24),
            Card(
              child: SwitchListTile(
                title: const Text('Asset is present'),
                subtitle: const Text('Confirm the physical asset is here.'),
                value: _present,
                onChanged: _submitting ? null : (value) => setState(() => _present = value),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: 'Observed location',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter the observed location'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AssetCondition>(
              initialValue: _condition,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Observed condition',
                border: OutlineInputBorder(),
              ),
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
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fact_check_outlined),
              label: Text(_submitting ? 'Submitting…' : 'Submit verification'),
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
                message: result.message ??
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
