import 'package:coregrid_mobile/features/assets/assets_api.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_detail.dart';
import 'package:coregrid_mobile/features/dashboard/widgets/find_asset_card.dart';
import 'package:coregrid_mobile/shared/api/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAssetsApi extends Fake implements AssetsApi {
  _FakeAssetsApi({this.knownCode});

  final String? knownCode;
  final looked = <String>[];

  @override
  Future<AssetDetail> getByCode(String assetCode) async {
    looked.add(assetCode);
    if (assetCode == knownCode) {
      return AssetDetail.fromJson({
        'id': 'asset-1',
        'asset_code': assetCode,
        'name': 'Hydraulic Pump',
        'status': 'ACTIVE',
        'condition': 'GOOD',
        'attributes': [],
      });
    }
    throw ApiException(statusCode: 404, message: 'Asset not found.');
  }
}

/// Renders the card on `/` and records where it navigates to.
Widget _harness(_FakeAssetsApi api, List<String> visited) {
  Widget page(GoRouterState state) {
    visited.add(state.uri.toString());
    return Text('page ${state.uri}');
  }

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: FindAssetCard()),
      ),
      GoRoute(path: '/scan', builder: (_, s) => page(s)),
      GoRoute(path: '/assets/search', builder: (_, s) => page(s)),
      GoRoute(path: '/assets/:id', builder: (_, s) => page(s)),
    ],
  );
  return ProviderScope(
    overrides: [assetsApiProvider.overrideWith((ref) => api)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('an exact asset code opens the asset directly', (tester) async {
    final api = _FakeAssetsApi(knownCode: 'AST-00042');
    final visited = <String>[];
    await tester.pumpWidget(_harness(api, visited));

    await tester.enterText(find.byType(TextField), ' AST-00042 ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(api.looked, ['AST-00042']);
    expect(visited, ['/assets/asset-1']);
  });

  testWidgets('an unknown code falls through to search, pre-filled', (
    tester,
  ) async {
    final api = _FakeAssetsApi();
    final visited = <String>[];
    await tester.pumpWidget(_harness(api, visited));

    await tester.enterText(find.byType(TextField), 'pump');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(api.looked, ['pump']);
    expect(visited, ['/assets/search?q=pump']);
  });

  testWidgets('multi-word text skips the code lookup', (tester) async {
    final api = _FakeAssetsApi();
    final visited = <String>[];
    await tester.pumpWidget(_harness(api, visited));

    await tester.enterText(find.byType(TextField), 'air compressor');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(api.looked, isEmpty);
    expect(visited, ['/assets/search?q=air+compressor']);
  });

  testWidgets('scan button opens the scanner', (tester) async {
    final visited = <String>[];
    await tester.pumpWidget(_harness(_FakeAssetsApi(), visited));

    await tester.tap(find.text('Scan QR code'));
    await tester.pumpAndSettle();

    expect(visited, ['/scan']);
  });
}
