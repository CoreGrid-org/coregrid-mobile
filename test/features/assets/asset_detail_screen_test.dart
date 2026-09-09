import 'package:coregrid_mobile/features/assets/assets_api.dart';
import 'package:coregrid_mobile/features/assets/assets_providers.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_attribute.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_condition.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_detail.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_history_entry.dart';
import 'package:coregrid_mobile/features/assets/screens/asset/asset_detail_screen.dart';
import 'package:coregrid_mobile/shared/api/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAssetsApi implements AssetsApi {
  _FakeAssetsApi({this.detail, this.error});

  final AssetDetail? detail;
  final Object? error;
  AssetCondition? lastConditionUpdate;

  @override
  Future<AssetDetail> getById(String assetId) async {
    if (error != null) throw error!;
    return detail!;
  }

  @override
  Future<AssetDetail> getByCode(String assetCode) => getById(assetCode);

  @override
  Future<void> updateCondition({
    required String assetId,
    required AssetCondition condition,
  }) async {
    lastConditionUpdate = condition;
  }

  @override
  Future<List<AssetHistoryEntry>> getHistory(
    String assetId, {
    int page = 1,
    int pageSize = 50,
  }) async => const [];
}

AssetDetail _asset({
  String status = 'ACTIVE',
  String condition = 'GOOD',
  List<AssetAttribute> attributes = const [],
}) {
  return AssetDetail(
    id: 'a1',
    assetCode: 'AST-00042',
    name: 'Ingersoll Rand Compressor',
    assetTypeName: 'Air Compressor',
    departmentName: 'Workshop',
    locationName: 'Bay 3',
    status: status,
    conditionRaw: condition,
    acquisitionDate: DateTime(2023, 5, 1),
    acquisitionCost: 12500,
    residualValue: 8000,
    qrPayload: 'AST-00042',
    attributes: attributes,
  );
}

Widget _harness({
  required _FakeAssetsApi api,
  bool canVerify = false,
}) {
  return ProviderScope(
    overrides: [
      assetsApiProvider.overrideWith((ref) => api),
      canVerifyAssetsProvider.overrideWith((ref) => canVerify),
    ],
    child: const MaterialApp(home: AssetDetailScreen(assetId: 'a1')),
  );
}

void main() {
  testWidgets('renders custom attributes from their data type alone (FR-020)', (
    tester,
  ) async {
    final api = _FakeAssetsApi(
      detail: _asset(
        attributes: const [
          AssetAttribute(
            definitionId: 'd1',
            name: 'Serial Number',
            dataType: 'TEXT',
            isRequired: true,
            valueText: 'IR-99X',
          ),
          AssetAttribute(
            definitionId: 'd2',
            name: 'Tank Certified',
            dataType: 'BOOLEAN',
            isRequired: false,
            valueBoolean: true,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_harness(api: api));
    await tester.pumpAndSettle();

    expect(find.text('Serial Number'), findsOneWidget);
    expect(find.text('IR-99X'), findsOneWidget);
    expect(find.text('Tank Certified'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
  });

  testWidgets('Officer sees the Verify action', (tester) async {
    await tester.pumpWidget(
      _harness(api: _FakeAssetsApi(detail: _asset()), canVerify: true),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Verify'), findsOneWidget);
  });

  testWidgets('Staff never sees the Verify action (FR-024 AC4)', (tester) async {
    await tester.pumpWidget(
      _harness(api: _FakeAssetsApi(detail: _asset()), canVerify: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verify'), findsNothing);
    expect(find.text('Report Fault'), findsOneWidget);
  });

  testWidgets('Update Condition is offered for an active asset', (tester) async {
    await tester.pumpWidget(
      _harness(api: _FakeAssetsApi(detail: _asset(status: 'ACTIVE'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update Condition'), findsOneWidget);
  });

  testWidgets('Update Condition is hidden once the asset is disposed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(api: _FakeAssetsApi(detail: _asset(status: 'DISPOSED'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update Condition'), findsNothing);
  });

  testWidgets('shows "Asset not found" on a 404 (FR-024 AC2/A3)', (tester) async {
    final api = _FakeAssetsApi(
      error: ApiException(statusCode: 404, message: 'Asset not found.'),
    );

    await tester.pumpWidget(_harness(api: api));
    await tester.pumpAndSettle();

    expect(find.text('Asset not found'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
  });

  testWidgets('shows the offline state on a network error (FR-024 A4)', (
    tester,
  ) async {
    final api = _FakeAssetsApi(
      error: ApiException(
        statusCode: 0,
        message: 'offline',
        isNetworkError: true,
      ),
    );

    await tester.pumpWidget(_harness(api: api));
    await tester.pumpAndSettle();

    expect(find.text('You\'re offline'), findsOneWidget);
  });
}
