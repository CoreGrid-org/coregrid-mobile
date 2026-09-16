import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/api/api_exception.dart';
import '../../assets_providers.dart';
import '../../models/asset/asset_detail.dart';

class AssetLookupScreen extends ConsumerStatefulWidget {
  const AssetLookupScreen({super.key});

  @override
  ConsumerState<AssetLookupScreen> createState() =>
      _AssetLookupScreenState();
}

class _AssetLookupScreenState extends ConsumerState<AssetLookupScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const orange = Color(0xFFFF5A00);
  static const lightOrange = Color(0xFFFFF0E8);
  static const darkText = Color(0xFF202625);
  static const secondaryText = Color(0xFF59635F);

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

    ref.listen<AsyncValue<AssetDetail?>>(
      assetLookupControllerProvider,
      (_, next) {
        final asset = next.asData?.value;

        if (asset != null) {
          context.push('/assets/${asset.id}');
          ref.read(assetLookupControllerProvider.notifier).reset();
        }
      },
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'Look Up Asset',
          style: TextStyle(
            color: darkText,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(
          color: darkText,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ============================================================
                // HEADER - ICON + TITLE ON SAME LINE
                // ============================================================
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: lightOrange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.manage_search_rounded,
                        size: 32,
                        color: orange,
                      ),
                    ),

                    const SizedBox(width: 18),

                    const Expanded(
                      child: Text(
                        'Find an asset',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: darkText,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Description
                const Text(
                  'Enter the asset code printed on the label '
                  'to view its details.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: secondaryText,
                  ),
                ),

                const SizedBox(height: 28),

                // ============================================================
                // SEARCH CARD
                // ============================================================
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBF9),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFFFFE2D3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Asset code',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: darkText,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ======================================================
                      // ASSET CODE INPUT
                      // ======================================================
                      TextFormField(
                        controller: _controller,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(
                            RegExp(r'\s'),
                          ),
                        ],
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: darkText,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. AST-00042',
                          hintStyle: const TextStyle(
                            color: Color(0xFF9AA19E),
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: const Icon(
                            Icons.qr_code_2_rounded,
                            color: orange,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 17,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7E6),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7E6),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: orange,
                              width: 1.8,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.error,
                              width: 1.8,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter an asset code';
                          }

                          return null;
                        },
                        onFieldSubmitted: (_) => _lookup(),
                      ),

                      const SizedBox(height: 16),

                      // ======================================================
                      // FIND ASSET BUTTON
                      // ======================================================
                      SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: state.isLoading ? null : _lookup,
                          style: FilledButton.styleFrom(
                            backgroundColor: orange,
                            disabledBackgroundColor:
                                orange.withValues(alpha: 0.45),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: state.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.search_rounded,
                                  size: 22,
                                ),
                          label: Text(
                            state.isLoading
                                ? 'Looking up...'
                                : 'Find Asset',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ============================================================
                // ERROR MESSAGE
                // ============================================================
                if (state.hasError) ...[
                  const SizedBox(height: 18),
                  _LookupError(error: state.error!),
                ],

                const SizedBox(height: 24),

                // ============================================================
                // INFORMATION CARD
                // ============================================================
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9F8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFECEFED),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: lightOrange,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: orange,
                          size: 22,
                        ),
                      ),

                      const SizedBox(width: 14),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Where can I find the code?',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: darkText,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'The asset code is printed on the QR or '
                              'identification label attached to the asset.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ============================================================
                // QR SCANNER HINT
                // ============================================================
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: lightOrange,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.qr_code_scanner_rounded,
                        color: orange,
                        size: 22,
                      ),

                      SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          'You can also scan the QR code from the dashboard.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: darkText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
  const _LookupError({
    required this.error,
  });

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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD6D2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 21,
            color: Theme.of(context).colorScheme.error,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}