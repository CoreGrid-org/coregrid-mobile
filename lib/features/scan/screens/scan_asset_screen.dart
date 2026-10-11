import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// navigating. A match shows a confirmation card with the asset's
/// availability and a way into its record; a code that isn't registered shows
/// the scanned value so the user can tell a bad label from a misread. In
/// [identify] mode it pops with the resolved [AssetDetail] instead.
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
  String? _scannedCode;
  AssetDetail? _found;
  Future<void>? _stopping;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    // Frames keep arriving while stop() is in flight; claim the scan
    // synchronously so a burst of detections can't start overlapping
    // lookups that overwrite each other's result.
    if (_isResolving || _found != null || _lookupError != null) return;

    final code = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    if (code == null) return;

    _isResolving = true;
    _stopping = _scannerController.stop();
    await _resolve(code);
  }

  /// Resolves a scanned or typed code, then opens the asset or — in
  /// identify mode — returns it to the caller.
  Future<void> _resolve(String code) async {
    setState(() {
      _isResolving = true;
      _lookupError = null;
      _found = null;
      _scannedCode = code;
    });

    var result = await AsyncValue.guard<AssetDetail>(
      () => ref.read(assetsApiProvider).getByCode(code),
    );
    // A dropped connection or cold-start timeout on the first request
    // shouldn't cost the user a rescan — retry a transient failure once.
    if (result.error case ApiException(isNetworkError: true) when mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      result = await AsyncValue.guard<AssetDetail>(
        () => ref.read(assetsApiProvider).getByCode(code),
      );
    }
    if (!mounted) return;

    final asset = result.asData?.value;
    if (asset != null && widget.identify) {
      context.pop(asset);
      return;
    }

    if (asset != null) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _found = asset;
      _lookupError = result.error;
      _isResolving = false;
    });
  }

  void _openFound() {
    final asset = _found;
    if (asset == null) return;
    // The QR endpoint returns the authoritative AssetDetailDto. Passing it
    // renders details immediately; AssetDetailScreen also refreshes.
    context.pushReplacement('/assets/${asset.id}', extra: asset);
  }

  Future<void> _scanAgain() async {
    setState(() {
      _lookupError = null;
      _found = null;
      _scannedCode = null;
    });
    // Starting while the previous stop() is still settling is ignored by
    // the plugin and leaves a frozen preview.
    await _stopping;
    _stopping = null;
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
              // No scanWindow: its preview-to-image mapping under
              // BoxFit.cover is off on many Android devices, shrinking or
              // shifting the live area so labels inside the guide often went
              // unread. The guide is aiming help; the whole frame scans.
              MobileScanner(
                controller: _scannerController,
                tapToFocus: true,
                onDetect: _onDetect,
                errorBuilder: (context, error) => _CameraUnavailable(
                  message:
                      error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Camera access was not allowed.'
                      : 'The camera could not be started.',
                  onEnterCode: _enterCode,
                ),
              ),
              const _ScanGuide(),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  minimum: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: switch (_found) {
                      final asset? => _AssetFoundCard(
                        key: ValueKey('found-${asset.id}'),
                        asset: asset,
                        onOpen: _openFound,
                        onScanAgain: _scanAgain,
                      ),
                      null => _ScanStatus(
                        key: ValueKey(_lookupError == null ? 'idle' : 'error'),
                        isResolving: _isResolving,
                        error: _lookupError,
                        scannedCode: _scannedCode,
                        onScanAgain: _scanAgain,
                        onEnterCode: _enterCode,
                      ),
                    },
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

/// Dark result panel pinned under the scan window.
class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
        children: children,
      ),
    );
  }
}

class _ScanStatus extends StatelessWidget {
  const _ScanStatus({
    super.key,
    required this.isResolving,
    required this.error,
    required this.scannedCode,
    required this.onScanAgain,
    required this.onEnterCode,
  });

  final bool isResolving;
  final Object? error;
  final String? scannedCode;
  final VoidCallback onScanAgain;
  final VoidCallback onEnterCode;

  @override
  Widget build(BuildContext context) {
    if (isResolving) {
      return _ResultPanel(
        children: [
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
          ),
        ],
      );
    }

    final api = error is ApiException ? error as ApiException : null;
    if (api != null && api.isNotFound) {
      return _NotRegistered(
        code: scannedCode ?? '',
        onScanAgain: onScanAgain,
        onEnterCode: onEnterCode,
      );
    }

    final message = switch (api) {
      ApiException(isNetworkError: true) =>
        'You\'re offline. Connect to a network and scan again.',
      ApiException(:final message) => message,
      _ when error != null => 'Something went wrong. Scan again.',
      _ => 'Hold steady — the asset is checked as soon as the code is read.',
    };

    return _ResultPanel(
      children: [
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
    );
  }
}

/// The scanned value didn't match any asset the user can see (404).
class _NotRegistered extends StatelessWidget {
  const _NotRegistered({
    required this.code,
    required this.onScanAgain,
    required this.onEnterCode,
  });

  final String code;
  final VoidCallback onScanAgain;
  final VoidCallback onEnterCode;

  @override
  Widget build(BuildContext context) {
    final danger = AppColors.dark.danger;
    return _ResultPanel(
      children: [
        Row(
          children: [
            Icon(Icons.gpp_bad_outlined, color: danger, size: 28),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Asset not registered',
                style: context.text.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: danger.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppRadius.card / 2),
            border: Border.all(color: danger.withValues(alpha: 0.5)),
          ),
          child: Text(
            code,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'No asset with that QR code exists in your organisation. Check the '
          'label is a CoreGrid asset tag, or ask an administrator to register it.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.tonalIcon(
          onPressed: onScanAgain,
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
          label: const Text('Scan again'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: onEnterCode,
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          icon: const Icon(Icons.keyboard_outlined, size: 20),
          label: const Text('Enter code manually'),
        ),
      ],
    );
  }
}

/// Confirms a scanned code resolved to a registered asset and says whether
/// it's available, before the user opens the full record.
class _AssetFoundCard extends StatelessWidget {
  const _AssetFoundCard({
    super.key,
    required this.asset,
    required this.onOpen,
    required this.onScanAgain,
  });

  final AssetDetail asset;
  final VoidCallback onOpen;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final success = AppColors.dark.success;
    final (availability, tone) = _availabilityOf(asset.lifecycleStatus);
    final place = [
      asset.locationName,
      asset.departmentName,
    ].where((part) => part.isNotEmpty).join(' · ');

    return _ResultPanel(
      children: [
        Row(
          children: [
            Icon(Icons.verified_rounded, color: success, size: 28),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Asset found',
                style: context.text.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            StatusPill(availability, tone: tone),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          asset.name.isEmpty ? asset.assetCode : asset.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.titleLarge?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          [
            asset.assetCode,
            asset.assetTypeName,
          ].where((part) => part.isNotEmpty).join(' · '),
          style: const TextStyle(color: Colors.white70),
        ),
        if (place.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(Icons.place_outlined, color: Colors.white54, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  place,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new_rounded, size: 20),
          label: const Text('View asset details'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: onScanAgain,
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
          label: const Text('Scan another'),
        ),
      ],
    );
  }

  static (String, StatusTone) _availabilityOf(AssetLifecycleStatus status) =>
      switch (status) {
        AssetLifecycleStatus.active => ('Available', StatusTone.success),
        AssetLifecycleStatus.underMaintenance ||
        AssetLifecycleStatus.transferRequested => (
          status.label,
          StatusTone.warning,
        ),
        AssetLifecycleStatus.inTransit => (status.label, StatusTone.info),
        AssetLifecycleStatus.condemned ||
        AssetLifecycleStatus.disposalRequested ||
        AssetLifecycleStatus.disposed => (status.label, StatusTone.danger),
        AssetLifecycleStatus.unknown => ('Status unknown', StatusTone.neutral),
      };
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
