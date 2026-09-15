import 'package:coregrid_mobile/features/assets/assets_api.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_condition.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_detail.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_history_entry.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_search.dart';
import 'package:coregrid_mobile/features/assets/screens/asset/asset_detail_screen.dart';
import 'package:coregrid_mobile/features/assets/screens/asset/asset_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _SearchApi implements AssetsApi, SearchableAssetsApi {
  AssetDetail get asset => AssetDetail.fromJson({
    'id': 'asset-12345',
    'asset_code': 'asset-12345',
    'name': 'Hydraulic Pump',
    'asset_type_name': 'Equipment',
    'department_name': 'Operations',
    'location_name': 'Plant A - Section 3',
    'status': 'ACTIVE',
    'condition': 'GOOD',
    'acquisition_date': '2022-05-10',
    'attributes': [],
  });

  @override
  Future<AssetSearchResult> search(AssetSearchQuery query) async =>
      AssetSearchResult(items: [asset], page: 1, pageSize: 20, totalCount: 1);

  @override
  Future<AssetDetail> getById(String assetId) async => asset;

  @override
  Future<AssetDetail> getByCode(String assetCode) async => asset;

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

void main() {
  testWidgets('tapping a searched asset opens its detail screen', (tester) async {
    final router = GoRouter(
      initialLocation: '/assets/search',
      routes: [
        GoRoute(
          path: '/assets/search',
          builder: (context, state) => const AssetSearchScreen(),
        ),
        GoRoute(
          path: '/assets/:id',
          builder: (context, state) =>
              AssetDetailScreen(assetId: state.pathParameters['id']!),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [assetsApiProvider.overrideWith((ref) => _SearchApi())],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    final resultTile = find.byType(ListTile);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(resultTile);
    await tester.pumpAndSettle();

    expect(find.text('Hydraulic Pump'), findsOneWidget);
    expect(find.text('asset-12345'), findsNWidgets(2));
    expect(find.text('Attributes'), findsOneWidget);
  });
}
