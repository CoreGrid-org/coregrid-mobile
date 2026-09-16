import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../assets/assets_api.dart';
import '../../assets/models/asset/asset_detail.dart';
import '../../../shared/api/api_exception.dart';

/// FR-024's camera entry point. A successful QR read is resolved against the
/// API before navigation; the QR value is never treated as asset data itself.
class ScanAssetScreen extends ConsumerStatefulWidget {
  const ScanAssetScreen({super.key});

  @override
  ConsumerState<ScanAssetScreen> createState() => _ScanAssetScreenState();
}

class _ScanAssetScreenState extends ConsumerState<ScanAssetScreen> {
  final _scannerController = MobileScannerController(
    // Leave formats unrestricted: some asset labels use Micro QR or a
    // differently encoded QR variant that ML Kit does not report as qrCode.
    // The API, not the scanner, decides whether its value identifies an asset.
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 500,
    autoZoom: true,
  );
  bool _isResolving = false;
  Object? _lookupError;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isResolving) return;

    final code = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    if (code == null) return;

    setState(() {
      _isResolving = true;
      _lookupError = null;
    });
    await _scannerController.stop();

    final result = await AsyncValue.guard<AssetDetail>(
      () => ref.read(assetsApiProvider).getByCode(code),
    );
    if (!mounted) return;

    final asset = result.asData?.value;
    if (asset != null) {
      // The QR endpoint returns the authoritative AssetDetailDto. Passing it
      // renders details immediately; AssetDetailScreen also refreshes by id.
      context.pushReplacement('/assets/${asset.id}', extra: asset);
      return;
    }

    setState(() {
      _lookupError = result.error;
      _isResolving = false;
    });
  }

  Future<void> _scanAgain() async {
    setState(() => _lookupError = null);
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
        title: const Text('Scan Asset'),
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
            return _CameraPermissionDenied(onEnterCode: _enterCode);
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(
                builder: (context, constraints) => MobileScanner(
                  controller: _scannerController,
                  // Match the live recognition area to the on-screen frame,
                  // rather than displaying a guide that has no scan behaviour.
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
                    onEnterCode: _enterCode,
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
                    error: _lookupError,
                    onScanAgain: _scanAgain,
                    onEnterCode: _enterCode,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _enterCode() => context.pushReplacement('/assets');
}

class _ScanGuide extends StatelessWidget {
  const _ScanGuide();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 248,
          height: 248,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 3),
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}

class _ScanStatus extends StatelessWidget {
  const _ScanStatus({
    required this.isResolving,
    required this.error,
    required this.onScanAgain,
    required this.onEnterCode,
  });

  final bool isResolving;
  final Object? error;
  final VoidCallback onScanAgain;
  final VoidCallback onEnterCode;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;
    final message = switch (api) {
      ApiException(isNotFound: true) =>
        'No asset with that QR code exists in your organisation.',
      ApiException(isNetworkError: true) =>
        'You\'re offline. Connect to a network and scan again.',
      ApiException(:final message) => message,
      _ => 'Camera ready. Align the asset QR code inside the frame.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xE6202625),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isResolving) ...[
            const CircularProgressIndicator(color: Color(0xFFFF5A00)),
            const SizedBox(height: 12),
            const Text(
              'Looking up asset…',
              style: TextStyle(color: Colors.white),
            ),
          ] else ...[
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: error == null ? onEnterCode : onScanAgain,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFFB48A),
              ),
              icon: Icon(
                error == null
                    ? Icons.keyboard_outlined
                    : Icons.qr_code_scanner_rounded,
              ),
              label: Text(error == null ? 'Enter code instead' : 'Scan again'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CameraPermissionDenied extends StatelessWidget {
  const _CameraPermissionDenied({required this.onEnterCode});

  final VoidCallback onEnterCode;

  @override
  Widget build(BuildContext context) => _CameraUnavailable(
    message: 'Camera access is needed to scan an asset QR code. You can allow it in Settings or enter the code manually.',
    onEnterCode: onEnterCode,
    showSettings: true,
  );
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({
    required this.message,
    required this.onEnterCode,
    this.showSettings = false,
  });

  final String message;
  final VoidCallback onEnterCode;
  final bool showSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              style: const TextStyle(color: Colors.white, height: 1.45),
            ),
            const SizedBox(height: 20),
            if (showSettings)
              FilledButton(
                onPressed: openAppSettings,
                child: const Text('Open Settings'),
              ),
            if (showSettings) const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onEnterCode,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.keyboard_outlined),
              label: const Text('Enter asset code'),
            ),
          ],
        ),
      ),
    );
  }
}
