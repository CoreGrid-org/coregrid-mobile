import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../shared/api/api_exception.dart';
import '../../../shared/theme/app_theme.dart';
import '../../assets/assets_api.dart';
import '../transfers_providers.dart';

/// FR-046 — Scan-to-Confirm Receipt.
///
/// The officer scans the QR code on the physical asset being received. The
/// scanned value is the asset's `qr_payload` string (identical to what
/// Jayashan's [ScanAssetScreen] reads). The screen resolves it to an
/// [AssetDetail] via `GET /api/assets/qr/{code}`, extracts the asset id,
/// verifies it matches [transferId]'s expected asset, then calls
/// `POST /api/transfers/{transferId}/confirm-receipt`.
///
/// On success: navigates back to the transfer detail screen (pushReplacement).
/// On mismatch / error: shows an inline error and restarts the scanner.
class ConfirmReceiptScanScreen extends ConsumerStatefulWidget {
  const ConfirmReceiptScanScreen({super.key, required this.transferId});

  final String transferId;

  @override
  ConsumerState<ConfirmReceiptScanScreen> createState() =>
      _ConfirmReceiptScanScreenState();
}

class _ConfirmReceiptScanScreenState
    extends ConsumerState<ConfirmReceiptScanScreen> {
  final _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 500,
    autoZoom: true,
  );

  bool _isResolving = false;
  Object? _scanError;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isResolving) return;

    final code = capture.barcodes
        .map((b) => b.rawValue?.trim())
        .whereType<String>()
        .where((v) => v.isNotEmpty)
        .firstOrNull;
    if (code == null) return;

    setState(() {
      _isResolving = true;
      _scanError = null;
    });
    await _scannerController.stop();

    // Step 1: Resolve the QR payload to an AssetDetail so we know the asset id.
    final assetResult = await AsyncValue.guard<String>(() async {
      final asset = await ref.read(assetsApiProvider).getByCode(code);
      return asset.id;
    });

    if (!mounted) return;

    if (assetResult.hasError) {
      setState(() {
        _scanError = assetResult.error;
        _isResolving = false;
      });
      return;
    }

    // Step 2: Verify the scanned asset matches the transfer's expected asset.
    final transfer = ref.read(transferDetailProvider(widget.transferId));
    final expectedAssetId = transfer.asData?.value.assetId;

    if (expectedAssetId != null &&
        assetResult.asData?.value != expectedAssetId) {
      setState(() {
        _scanError = _AssetMismatchError();
        _isResolving = false;
      });
      return;
    }

    // Step 3: Call confirm-receipt.
    final confirmed = await ref
        .read(confirmReceiptControllerProvider.notifier)
        .confirm(widget.transferId);

    if (!mounted) return;

    if (confirmed) {
      context.pushReplacement('/transfers/${widget.transferId}');
      return;
    }

    final controllerState = ref.read(confirmReceiptControllerProvider);
    setState(() {
      _scanError = controllerState.error;
      _isResolving = false;
    });
  }

  Future<void> _scanAgain() async {
    setState(() => _scanError = null);
    await _scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    final permissionDenied =
        _scannerController.value.error?.errorCode ==
        MobileScannerErrorCode.permissionDenied;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan to Confirm Receipt'),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _scannerController,
            builder: (context, state, _) => IconButton(
              tooltip: state.torchState == TorchState.on
                  ? 'Turn off flashlight'
                  : 'Turn on flashlight',
              onPressed: state.isRunning
                  ? _scannerController.toggleTorch
                  : null,
              icon: Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
              ),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<MobileScannerState>(
        valueListenable: _scannerController,
        builder: (context, scannerState, _) {
          final isPermissionDenied =
              scannerState.error?.errorCode ==
              MobileScannerErrorCode.permissionDenied;
          if (isPermissionDenied || permissionDenied) {
            return _CameraPermissionDenied(onCancel: () => context.pop());
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(
                builder: (context, constraints) => MobileScanner(
                  controller: _scannerController,
                  scanWindow: Rect.fromCenter(
                    center: constraints.biggest.center(Offset.zero),
                    width: 248,
                    height: 248,
                  ),
                  tapToFocus: true,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => _CameraUnavailable(
                    message:
                        error.errorCode ==
                            MobileScannerErrorCode.permissionDenied
                        ? 'Camera access was not allowed.'
                        : 'The camera could not be started.',
                    onCancel: () => context.pop(),
                  ),
                ),
              ),
              const _ScanGuide(),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  minimum: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                  child: _ScanStatus(
                    isResolving: _isResolving,
                    error: _scanError,
                    onScanAgain: _scanAgain,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Private helper widgets (mirrors scan_asset_screen.dart) ──────────────────

class _ScanGuide extends StatelessWidget {
  const _ScanGuide();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Center(
      child: Container(
        width: 248,
        height: 248,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 3),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
    ),
  );
}

class _ScanStatus extends StatelessWidget {
  const _ScanStatus({
    required this.isResolving,
    required this.error,
    required this.onScanAgain,
  });

  final bool isResolving;
  final Object? error;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final message = switch (error) {
      _AssetMismatchError() =>
        'Wrong asset. Scan the QR code on the asset listed in this transfer.',
      ApiException(isNotFound: true) =>
        'No asset with that QR code found in your organisation.',
      ApiException(isNetworkError: true) =>
        'You\'re offline. Connect to a network and scan again.',
      ApiException(:final message) => message,
      null => 'Camera ready. Align the asset\'s QR code inside the frame.',
      _ => 'Something went wrong. Try scanning again.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xE6202625),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isResolving) ...[
            const CircularProgressIndicator(color: Color(0xFFFF5A00)),
            const SizedBox(height: 12),
            const Text(
              'Confirming receipt…',
              style: TextStyle(color: Colors.white),
            ),
          ] else ...[
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, height: 1.35),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onScanAgain,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFFB48A),
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan again'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CameraPermissionDenied extends StatelessWidget {
  const _CameraPermissionDenied({required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.no_photography_outlined,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Camera access is needed to scan the asset QR code. '
            'Allow it in Settings or go back.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, height: 1.45),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: openAppSettings,
            child: const Text('Open Settings'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Go back'),
          ),
        ],
      ),
    ),
  );
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.message, required this.onCancel});
  final String message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.no_photography_outlined,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Go back'),
          ),
        ],
      ),
    ),
  );
}

/// Sentinel error thrown when the scanned asset id does not match the
/// transfer's expected asset — distinct from an API/network failure so
/// [_ScanStatus] can show the specific "wrong asset" message.
class _AssetMismatchError implements Exception {}
