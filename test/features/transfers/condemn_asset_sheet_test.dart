import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_detail.dart';
import 'package:coregrid_mobile/features/transfers/screens/condemn_asset_sheet.dart';

AssetDetail _createFakeAsset({
  required String conditionRaw,
  String status = 'ACTIVE',
}) {
  return AssetDetail(
    id: '00000000-0000-0000-0000-000000000001',
    assetCode: 'AST-00999',
    name: 'Workstation ThinkPad P1',
    assetTypeName: 'IT Equipment',
    departmentName: 'Engineering',
    locationName: 'Floor 3 Lab',
    status: status,
    conditionRaw: conditionRaw,
    acquisitionDate: DateTime(2025, 1, 1),
    acquisitionCost: 2500,
    residualValue: 500,
    qrPayload: 'https://coregrid.example.com/assets/AST-00999',
    attributes: const [],
  );
}

void main() {
  group('CondemnAssetSheet - Condition Guard & Flow (FR-049)', () {
    testWidgets('shows condition-ineligible warning when condition is Good', (tester) async {
      final goodAsset = _createFakeAsset(conditionRaw: 'Good');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => CondemnAssetSheet.show(context, asset: goodAsset),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Warning banner present
      expect(find.text('Condition Ineligible for Condemnation'), findsOneWidget);
      expect(find.textContaining('Condemnation requires a recorded condition of Poor or Unserviceable'), findsOneWidget);
      expect(find.text('Update Condition First'), findsOneWidget);

      // Form fields NOT present
      expect(find.text('Reason for Condemnation *'), findsNothing);
      expect(find.text('Take Photo'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Condemn Asset'), findsNothing);
    });

    testWidgets('shows condemnation form when condition is Poor', (tester) async {
      final poorAsset = _createFakeAsset(conditionRaw: 'Poor');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => CondemnAssetSheet.show(context, asset: poorAsset),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Guard is NOT present
      expect(find.text('Condition Ineligible for Condemnation'), findsNothing);

      // Form fields ARE present
      expect(find.textContaining('will be permanently marked as Condemned'), findsOneWidget);
      expect(find.text('Reason for Condemnation *'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose Photo'), findsOneWidget);
      expect(find.text('Evidence URL (optional)'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Condemn Asset'), findsOneWidget);
    });

    testWidgets('shows condemnation form when condition is Unserviceable', (tester) async {
      final unserviceableAsset = _createFakeAsset(conditionRaw: 'Unserviceable');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => CondemnAssetSheet.show(context, asset: unserviceableAsset),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Condition Ineligible for Condemnation'), findsNothing);
      expect(find.text('Reason for Condemnation *'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Condemn Asset'), findsOneWidget);
    });
  });
}
