import 'package:coregrid_mobile/features/assets/models/asset/asset_detail.dart';
import 'package:coregrid_mobile/features/verification/models/verification_location.dart';
import 'package:coregrid_mobile/features/verification/models/verification_task.dart';
import 'package:coregrid_mobile/features/verification/screens/verification_task_detail_screen.dart';
import 'package:coregrid_mobile/features/verification/screens/verification_task_list_screen.dart';
import 'package:coregrid_mobile/features/verification/verification_api.dart';
import 'package:coregrid_mobile/features/verification/verify_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

VerificationTask _task() => VerificationTask.fromJson({
  'id': 't1',
  'campaign_id': 'c1',
  'campaign_name': 'Q3 Audit',
  'asset_id': 'a1',
  'asset_code': 'AST-001',
  'asset_name': 'Generator',
  'due_date': '2099-01-01',
  'status': 'Pending',
});

AssetDetail _asset(String id, String code) => AssetDetail.fromJson({
  'id': id,
  'asset_code': code,
  'name': 'Generator',
  'status': 'ACTIVE',
  'condition': 'GOOD',
  'attributes': [],
});

class _Api extends Fake implements VerificationApi {
  bool? completedPresent;

  @override
  Future<List<VerificationTask>> getTasks({
    bool mine = true,
    bool onlyPending = false,
  }) async => [_task()];

  @override
  Future<List<VerificationLocation>> getLocations() async => const [];

  @override
  Future<VerificationTask> completeTask({
    required String taskId,
    required bool assertedPresent,
    String? assertedLocationId,
    String? assertedCondition,
  }) async {
    completedPresent = assertedPresent;
    return _task();
  }
}

/// The detail screen pushed over a home route, so `context.pop()` after a
/// successful submit has somewhere to return to.
Future<void> _pumpDetail(
  WidgetTester tester,
  _Api api, {
  bool scanned = false,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('home')),
      GoRoute(
        path: '/task',
        builder: (_, _) =>
            VerificationTaskDetailScreen(taskId: 't1', scanned: scanned),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [verificationApiProvider.overrideWith((ref) => api)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push('/task');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('FR-059: "Present" cannot be submitted without a scan', (
    tester,
  ) async {
    final api = _Api();
    await _pumpDetail(tester, api);

    expect(find.text('Scan to confirm'), findsOneWidget);
    await tester.ensureVisible(find.text('Submit verification'));
    await tester.tap(find.text('Submit verification'));
    await tester.pumpAndSettle();

    expect(
      find.text('Scan the asset\'s QR label before marking it present.'),
      findsOneWidget,
    );
    expect(api.completedPresent, isNull);
  });

  testWidgets('"Not found" needs no scan — a missing asset can\'t be scanned', (
    tester,
  ) async {
    final api = _Api();
    await _pumpDetail(tester, api);

    await tester.ensureVisible(find.text('Not found'));
    await tester.tap(find.text('Not found'));
    await tester.pumpAndSettle();
    expect(find.text('Scan to confirm'), findsNothing);

    await tester.ensureVisible(find.text('Submit verification'));
    await tester.tap(find.text('Submit verification'));
    await tester.pumpAndSettle();

    expect(api.completedPresent, isFalse);
  });

  testWidgets('arriving from Scan to verify counts as confirmed', (
    tester,
  ) async {
    await _pumpDetail(tester, _Api(), scanned: true);

    expect(find.textContaining('Identity confirmed'), findsOneWidget);
  });

  group('openVerificationFor', () {
    Future<List<String>> run(WidgetTester tester, AssetDetail asset) async {
      final visited = <String>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () =>
                    openVerificationFor(context, ref, asset, scanned: true),
                child: const Text('go'),
              ),
            ),
          ),
          GoRoute(
            path: '/verification/:id',
            builder: (_, s) {
              visited.add(s.uri.toString());
              return const Text('task');
            },
          ),
          GoRoute(
            path: '/assets/:id/verify',
            builder: (_, s) {
              visited.add(s.uri.toString());
              return const Text('ad-hoc');
            },
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [verificationApiProvider.overrideWith((ref) => _Api())],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      return visited;
    }

    testWidgets('opens the officer\'s pending task, already confirmed', (
      tester,
    ) async {
      final visited = await run(tester, _asset('a1', 'AST-001'));
      expect(visited, ['/verification/t1?scanned=1']);
    });

    testWidgets('offers ad-hoc verification (FR-031) when no task covers it', (
      tester,
    ) async {
      final visited = await run(tester, _asset('a9', 'AST-009'));
      expect(find.text('No task for this asset'), findsOneWidget);

      await tester.tap(find.text('Verify anyway'));
      await tester.pumpAndSettle();
      expect(visited, ['/assets/a9/verify']);
    });
  });

  group('scan button on a task row', () {
    Future<List<String>> run(WidgetTester tester, AssetDetail scanned) async {
      final visited = <String>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: ListView(children: [TaskTile(task: _task())]),
            ),
          ),
          GoRoute(
            path: '/scan',
            builder: (context, _) => TextButton(
              onPressed: () => context.pop(scanned),
              child: const Text('scanned'),
            ),
          ),
          GoRoute(
            path: '/verification/:id',
            builder: (_, s) {
              visited.add(s.uri.toString());
              return const Text('task');
            },
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.byTooltip('Scan AST-001'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('scanned'));
      await tester.pumpAndSettle();
      return visited;
    }

    testWidgets('opens the task already confirmed when the label matches', (
      tester,
    ) async {
      final visited = await run(tester, _asset('a1', 'AST-001'));
      expect(visited, ['/verification/t1?scanned=1']);
    });

    testWidgets('names the wrong asset when the label doesn\'t match', (
      tester,
    ) async {
      final visited = await run(tester, _asset('a9', 'AST-009'));
      expect(visited, isEmpty);
      expect(find.textContaining('That label is AST-009'), findsOneWidget);
    });
  });
}
