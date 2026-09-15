import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/api/api_exception.dart';
import '../../assets_providers.dart';
import '../../models/asset/asset_detail.dart';

/// Manual asset-code entry (FR-025) — the always-available way to reach an
/// asset record without the camera. Route: `/assets`.
///
/// This is the minimal version that also serves as the reachable entry point
/// to [AssetDetailScreen] until `features/scan/` lands; the full scanner +
/// permission-fallback flow (FR-024, IF-10) folds this in there.
class AssetLookupScreen extends ConsumerStatefulWidget {
  const AssetLookupScreen({super.key});

  @override
  ConsumerState<AssetLookupScreen> createState() => _AssetLookupScreenState();
}

class _AssetLookupScreenState extends ConsumerState<AssetLookupScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(assetLookupControllerProvider.notifier)
        .lookup(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assetLookupControllerProvider);

    // On a successful resolve, go to the detail screen. AC3: resolving by code
    // and by id return the same record.
    ref.listen<AsyncValue<AssetDetail?>>(assetLookupControllerProvider, (
      _,
      next,
    ) {
      final asset = next.asData?.value;
      if (asset != null) {
        context.push('/assets/${asset.id}');
        ref.read(assetLookupControllerProvider.notifier).reset();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Look Up Asset')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter the asset code printed on the label.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Asset code',
                    hintText: 'e.g. AST-00042',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                      ? 'Enter an asset code'
                      : null,
                  onFieldSubmitted: (_) => _lookup(),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: state.isLoading ? null : _lookup,
                  icon: state.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(state.isLoading ? 'Looking up…' : 'Find asset'),
                ),
                const SizedBox(height: 16),
                if (state.hasError) _LookupError(error: state.error!),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _LookupError extends StatelessWidget {
  const _LookupError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error : null;
    final message = switch (api) {
      // AC2/A3 — a code from another organisation comes back as 404, and we
      // say nothing about whether it exists elsewhere.
      ApiException(isNotFound: true) =>
        'No asset with that code exists in your organisation.',
      ApiException(isNetworkError: true) =>
        'You\'re offline. Connect to a network and try again.',
      ApiException(:final message) => message,
      _ => 'Something went wrong. Try again.',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.error_outline,
          size: 18,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}

