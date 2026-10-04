import 'package:coregrid_mobile/features/assets/assets_api.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_detail.dart';
import 'package:coregrid_mobile/features/scan/screens/scan_asset_screen.dart';
import 'package:coregrid_mobile/shared/api/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class _FakeAssetsApi extends Fake implements AssetsApi {
  _FakeAssetsApi();

  String? knownCode = 'AST-00042';
  bool throwOffline = false;
  final lookedUpCodes = <String>[];

  @override
  Future<AssetDetail> getByCode(String assetCode) async {
    lookedUpCodes.add(assetCode);

    if (throwOffline) {
      throw ApiException(
        statusCode: 0,
        message: 'You\'re offline. Connect to a network and scan again.',
        isNetworkError: true,
      );
    }

    if (assetCode == knownCode) {
      return AssetDetail.fromJson({
        'id': 'asset-123',
        'asset_code': assetCode,
        'name': 'Hydraulic Pump',
        'status': 'ACTIVE',
        'condition': 'GOOD',
        'attributes': [],
      });
    }

    throw ApiException(
      statusCode: 404,
      message: 'No asset with that QR code exists in your organisation.',
    );
  }
}

Widget _buildHarness({
  required _FakeAssetsApi api,
  required List<String> navigationLog,
  bool identify = false,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              if (identify) {
                final asset = await identifyAssetByScan(context);
                if (asset != null) {
                  navigationLog.add('popped:${asset.id}');
                }
              } else {
                context.push('/scan');
              }
            },
            child: const Text('Open Scanner'),
          ),
        ),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) {
          final isIdentify =
              identify || state.uri.queryParameters['purpose'] == 'identify';
          return ScanAssetScreen(identify: isIdentify);
        },
      ),
      GoRoute(
        path: '/assets',
        builder: (_, state) {
          navigationLog.add(state.uri.toString());
          return const Scaffold(body: Text('Assets Screen'));
        },
      ),
      GoRoute(
        path: '/assets/:id',
        builder: (_, state) {
          navigationLog.add(state.uri.toString());
          return Scaffold(body: Text('Asset Detail: ${state.pathParameters['id']}'));
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [assetsApiProvider.overrideWith((ref) => api)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScanAssetScreen Widget Tests', () {
    late _FakeAssetsApi api;
    late List<String> navigationLog;

    setUp(() {
      api = _FakeAssetsApi();
      navigationLog = <String>[];
    });

    testWidgets('camera success - scans valid code and navigates to asset record', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(api: api, navigationLog: navigationLog),
      );

      // Navigate to /scan
      await tester.tap(find.text('Open Scanner'));
      await tester.pumpAndSettle();

      expect(find.byType(ScanAssetScreen), findsOneWidget);

      // Simulate QR detection on MobileScanner
      final mobileScanner = tester.widget<MobileScanner>(
        find.byType(MobileScanner),
      );
      mobileScanner.onDetect!(
        const BarcodeCapture(
          barcodes: [Barcode(rawValue: 'AST-00042')],
        ),
      );

      await tester.pumpAndSettle();

      expect(api.lookedUpCodes, contains('AST-00042'));
      expect(navigationLog, contains('/assets/asset-123'));
    });

    testWidgets('camera success - identify mode pops with resolved AssetDetail', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(api: api, navigationLog: navigationLog, identify: true),
      );

      await tester.tap(find.text('Open Scanner'));
      await tester.pumpAndSettle();

      expect(find.text('Scan to confirm'), findsOneWidget);

      final mobileScanner = tester.widget<MobileScanner>(
        find.byType(MobileScanner),
      );
      mobileScanner.onDetect!(
        const BarcodeCapture(
          barcodes: [Barcode(rawValue: 'AST-00042')],
        ),
      );

      await tester.pumpAndSettle();

      expect(api.lookedUpCodes, contains('AST-00042'));
      expect(navigationLog, contains('popped:asset-123'));
    });

    testWidgets('permission refusal - shows permission denied view and settings option', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(api: api, navigationLog: navigationLog),
      );

      await tester.tap(find.text('Open Scanner'));
      await tester.pumpAndSettle();

      // Access controller via public MobileScanner widget in the tree
      final mobileScanner = tester.widget<MobileScanner>(
        find.byType(MobileScanner),
      );
      mobileScanner.controller!.value = MobileScannerState(
        isInitialized: false,
        availableCameras: 0,
        cameraDirection: CameraFacing.back,
        cameraLensType: CameraLensType.values.first,
        deviceOrientation: DeviceOrientation.portraitUp,
        isRunning: false,
        isStarting: false,
        size: Size.zero,
        torchState: TorchState.off,
        zoomScale: 1.0,
        error: const MobileScannerException(
          errorCode: MobileScannerErrorCode.permissionDenied,
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text(
          'Camera access is needed to scan an asset QR code. You can allow it in Settings or enter the code manually.',
        ),
        findsOneWidget,
      );
      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.text('Enter asset code'), findsOneWidget);
    });

    testWidgets('unknown code - displays 404 error message and scan again option', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(api: api, navigationLog: navigationLog),
      );

      await tester.tap(find.text('Open Scanner'));
      await tester.pumpAndSettle();

      // Scan unknown code
      final mobileScanner = tester.widget<MobileScanner>(
        find.byType(MobileScanner),
      );
      mobileScanner.onDetect!(
        const BarcodeCapture(
          barcodes: [Barcode(rawValue: 'AST-UNKNOWN')],
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('No asset with that QR code exists in your organisation.'),
        findsOneWidget,
      );
      expect(find.text('Scan again'), findsOneWidget);

      // Tap Scan again to clear error state
      await tester.tap(find.text('Scan again'));
      await tester.pumpAndSettle();

      expect(
        find.text('Hold steady — the asset opens as soon as the code is read.'),
        findsOneWidget,
      );
    });

    testWidgets('offline recovery - handles network error and recovers on scan again', (
      tester,
    ) async {
      api.throwOffline = true;

      await tester.pumpWidget(
        _buildHarness(api: api, navigationLog: navigationLog),
      );

      await tester.tap(find.text('Open Scanner'));
      await tester.pumpAndSettle();

      // Scan while offline
      final mobileScanner = tester.widget<MobileScanner>(
        find.byType(MobileScanner),
      );
      mobileScanner.onDetect!(
        const BarcodeCapture(
          barcodes: [Barcode(rawValue: 'AST-00042')],
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('You\'re offline. Connect to a network and scan again.'),
        findsOneWidget,
      );
      expect(find.text('Scan again'), findsOneWidget);

      // Restore network connectivity and retry
      api.throwOffline = false;
      await tester.tap(find.text('Scan again'));
      await tester.pumpAndSettle();

      // Re-trigger scan
      final reScanner = tester.widget<MobileScanner>(
        find.byType(MobileScanner),
      );
      reScanner.onDetect!(
        const BarcodeCapture(
          barcodes: [Barcode(rawValue: 'AST-00042')],
        ),
      );

      await tester.pumpAndSettle();

      expect(navigationLog, contains('/assets/asset-123'));
    });

    testWidgets('manual-entry fallback - non-identify mode navigates to asset list', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(api: api, navigationLog: navigationLog),
      );

      await tester.tap(find.text('Open Scanner'));
      await tester.pumpAndSettle();

      expect(find.text('Enter code instead'), findsOneWidget);
      await tester.tap(find.text('Enter code instead'));
      await tester.pumpAndSettle();

      expect(navigationLog, contains('/assets'));
    });

    testWidgets('manual-entry fallback - identify mode dialog resolves entered code', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(api: api, navigationLog: navigationLog, identify: true),
      );

      await tester.tap(find.text('Open Scanner'));
      await tester.pumpAndSettle();

      expect(find.text('Enter code instead'), findsOneWidget);
      await tester.tap(find.text('Enter code instead'));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Enter asset code'), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'AST-00042');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(api.lookedUpCodes, contains('AST-00042'));
      expect(navigationLog, contains('popped:asset-123'));
    });
  });
}
