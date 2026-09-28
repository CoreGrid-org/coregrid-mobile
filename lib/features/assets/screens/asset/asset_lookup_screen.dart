import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/api/api_exception.dart';
import '../../../../shared/widgets/ui.dart';
import '../../assets_providers.dart';
import '../../models/asset/asset_detail.dart';

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
        .lookup(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assetLookupControllerProvider);

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
      appBar: AppBar(title: const Text('Enter asset code')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: AppSpacing.pageInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Type the code printed on the asset\'s label to open its record.',
                style: context.mutedBody,
              ),
              const SizedBox(height: AppSpacing.xl),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _controller,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                        style: context.text.titleMedium,
                        decoration: const InputDecoration(
                          labelText: 'Asset code',
                          hintText: 'e.g. AST-00042',
                          prefixIcon: Icon(Icons.qr_code_2_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter an asset code';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _lookup(),
                      ),
                      if (state.hasError) ...[
                        const SizedBox(height: AppSpacing.md),
                        _LookupError(error: state.error!),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      SubmitButton(
                        label: 'Find Asset',
                        busyLabel: 'Looking up...',
                        icon: Icons.search_rounded,
                        busy: state.isLoading,
                        onPressed: _lookup,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Notice(
                icon: Icons.sell_outlined,
                title: 'Where can I find the code?',
                message:
                    'It\'s printed under the QR code on the identification '
                    'label attached to the asset.',
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: () => context.pushReplacement('/scan'),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan the QR code instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ERROR WIDGET
// ============================================================================

class _LookupError extends StatelessWidget {
  const _LookupError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;

    final message = switch (api) {
      ApiException(isNotFound: true) =>
        'No asset with that code exists in your organisation.',
      ApiException(isNetworkError: true) =>
        'You\'re offline. Connect to a network and try again.',
      ApiException(:final message) => message,
      _ => 'Something went wrong. Try again.',
    };

    return Notice(tone: StatusTone.danger, message: message);
  }
}
