import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../assets/assets_api.dart';
import '../../assets/models/asset/asset_detail.dart';
import '../../../shared/api/api_exception.dart';
import '../../../shared/widgets/ui.dart';

/// Opens the scanner in identify mode and returns the resolved asset, or
/// null if the user backs out. Used where a scan *proves* the user is at a
/// specific asset (FR-059 verification) rather than to browse it.
Future<AssetDetail?> identifyAssetByScan(BuildContext context) =>
    context.push<AssetDetail>('/scan?purpose=identify');

/// QR code scanner screen — resolves scanned codes against the API before
/// navigating. In [identify] mode it pops with the resolved [AssetDetail]
/// instead of opening the asset record.
class ScanAssetScreen extends ConsumerStatefulWidget {
  const ScanAssetScreen({super.key, this.identify = false});

  final bool identify;

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

    await _scannerController.stop();
    await _resolve(code);
  }

  /// Resolves a scanned or typed code, then opens the asset or — in
  /// identify mode — returns it to the caller.
  Future<void> _resolve(String code) async {
    setState(() {
      _isResolving = true;
      _lookupError = null;
    });

    final result = await AsyncValue.guard<AssetDetail>(
      () => ref.read(assetsApiProvider).getByCode(code),
    );
    if (!mounted) return;

    final asset = result.asData?.value;
    if (asset != null) {
      if (widget.identify) {
        context.pop(asset);
      } else {
        // The QR endpoint returns the authoritative AssetDetailDto. Passing
        // it renders details immediately; AssetDetailScreen also refreshes.
        context.pushReplacement('/assets/${asset.id}', extra: asset);
      }
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: context.text.titleLarge?.copyWith(color: Colors.white),
        title: Text(widget.identify ? 'Scan to confirm' : 'Scan asset'),
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
                    width: _ScanGuide.size,
                    height: _ScanGuide.size,
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

  /// IF-10 fallback. Browsing hands off to the manual-entry screen; identify
  /// mode asks for the code in place so the result still returns here.
  Future<void> _enterCode() async {
    if (!widget.identify) {
      context.pushReplacement('/assets');
      return;
    }
    final code = await showDialog<String>(
      context: context,
      builder: (context) => const _EnterCodeDialog(),
    );
    if (code != null && code.isNotEmpty && mounted) await _resolve(code);
  }
}

/// Dims everything outside the live scan window and draws corner brackets
/// around it, so the recognition area is unmistakable.
class _ScanGuide extends StatelessWidget {
  const _ScanGuide();

  static const size = 248.0;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScanOverlayPainter(
          window: size,
          accent: context.colors.primaryContainer,
        ),
        child: Align(
          alignment: const Alignment(0, 0.42),
          child: Padding(
            padding: const EdgeInsets.only(top: size / 2 + 48),
            child: Text(
              'Align the QR label inside the frame',
              style: context.text.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  _ScanOverlayPainter({required this.window, required this.accent});

  final double window;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: window,
      height: window,
    );
    final hole = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(hole),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    const len = 34.0;
    final paint = Paint()
      ..color = accent
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final (corner, dx, dy) in [
      (rect.topLeft, 1.0, 1.0),
      (rect.topRight, -1.0, 1.0),
      (rect.bottomLeft, 1.0, -1.0),
      (rect.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx, corner.dy + dy * len)
          ..lineTo(corner.dx, corner.dy + dy * 12)
          ..quadraticBezierTo(
            corner.dx,
            corner.dy,
            corner.dx + dx * 12,
            corner.dy,
          )
          ..lineTo(corner.dx + dx * len, corner.dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) =>
      old.window != window || old.accent != accent;
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
      _ => 'Hold steady — the asset opens as soon as the code is read.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: CoreGridBrand.ink.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isResolving)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: context.colors.primaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Text(
                  'Looking up asset…',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  error == null ? Icons.qr_code_2 : Icons.error_outline,
                  color: error == null ? Colors.white70 : AppColors.dark.danger,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, height: 1.35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonalIcon(
              onPressed: error == null ? onEnterCode : onScanAgain,
              icon: Icon(
                error == null
                    ? Icons.keyboard_outlined
                    : Icons.qr_code_scanner_rounded,
                size: 20,
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
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white,
              size: 56,
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
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
              icon: const Icon(Icons.keyboard_outlined),
              label: const Text('Enter asset code'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnterCodeDialog extends StatefulWidget {
  const _EnterCodeDialog();

  @override
  State<_EnterCodeDialog> createState() => _EnterCodeDialogState();
}

class _EnterCodeDialogState extends State<_EnterCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter asset code'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _done(),
        decoration: const InputDecoration(hintText: 'e.g. AST-00042'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _done, child: const Text('Confirm')),
      ],
    );
  }
}
