import 'package:coregrid_mobile/features/assets/assets_api.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_condition.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_detail.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_history_entry.dart';
import 'package:coregrid_mobile/features/assets/screens/asset/asset_lookup_screen.dart';
import 'package:coregrid_mobile/shared/api/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAssetsApi implements AssetsApi {
  _FakeAssetsApi({this.error});

  final Object? error;
  String? lastCodeLookedUp;

  @override
  Future<AssetDetail> getByCode(String assetCode) async {
    lastCodeLookedUp = assetCode;
    throw error ?? ApiException(statusCode: 404, message: 'Asset not found.');
  }

  @override
  Future<AssetDetail> getById(String assetId) => getByCode(assetId);

  @override
  Future<void> updateCondition({
    required String assetId,
    required AssetCondition condition,
  }) async {}

  @override
  Future<List<AssetHistoryEntry>> getHistory(
    String assetId, {
    int page = 1,
    int pageSize = 50,
  }) async => const [];
}

Widget _harness(_FakeAssetsApi api) {
  return ProviderScope(
    overrides: [assetsApiProvider.overrideWith((ref) => api)],
    child: const MaterialApp(home: AssetLookupScreen()),
  );
}

void main() {
  testWidgets('validates that a code was entered', (tester) async {
    final api = _FakeAssetsApi();
    await tester.pumpWidget(_harness(api));

    await tester.tap(find.widgetWithText(FilledButton, 'Find asset'));
    await tester.pump();

    expect(find.text('Enter an asset code'), findsOneWidget);
    expect(api.lastCodeLookedUp, isNull);
  });

  testWidgets('shows a non-leaking message for a code not in the org (AC2/A3)', (
    tester,
  ) async {
    final api = _FakeAssetsApi(
      error: ApiException(statusCode: 404, message: 'Asset not found.'),
    );
    await tester.pumpWidget(_harness(api));

    await tester.enterText(find.byType(TextFormField), 'AST-99999');
    await tester.tap(find.widgetWithText(FilledButton, 'Find asset'));
    await tester.pumpAndSettle();

    expect(
      find.text('No asset with that code exists in your organisation.'),
      findsOneWidget,
    );
  });

  testWidgets('shows the offline message on a network error (A4)', (
    tester,
  ) async {
    final api = _FakeAssetsApi(
      error: ApiException(
        statusCode: 0,
        message: 'offline',
        isNetworkError: true,
      ),
    );
    await tester.pumpWidget(_harness(api));

    await tester.enterText(find.byType(TextFormField), 'AST-1');
    await tester.tap(find.widgetWithText(FilledButton, 'Find asset'));
    await tester.pumpAndSettle();

    expect(
      find.text('You\'re offline. Connect to a network and try again.'),
      findsOneWidget,
    );
  });
}
