import 'package:coregrid_mobile/features/workflows/models/agent_workflow.dart';
import 'package:coregrid_mobile/features/workflows/models/workflow_asset_ref.dart';
import 'package:coregrid_mobile/features/workflows/models/workflow_asset_type.dart';
import 'package:coregrid_mobile/features/workflows/screens/initiate_workflow_screen.dart';
import 'package:coregrid_mobile/features/workflows/workflows_api.dart';
import 'package:coregrid_mobile/shared/api/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeWorkflowsApi implements WorkflowsApi {
  _FakeWorkflowsApi({this.assetError, this.assetTypeId = ''});

  final Object? assetError;
  final String assetTypeId;
  String? lastObjective;
  String? lastAssetId;
  String? lastAssetTypeId;

  @override
  Future<List<WorkflowAssetType>> getAssetTypes() async => const [
    WorkflowAssetType(
      id: 't1',
      name: 'Generator',
      categoryId: 'c1',
      categoryName: 'Power',
    ),
    WorkflowAssetType(
      id: 't2',
      name: 'Transformer',
      categoryId: 'c1',
      categoryName: 'Power',
    ),
    WorkflowAssetType(
      id: 't3',
      name: 'Laptop',
      categoryId: 'c2',
      categoryName: 'IT equipment',
    ),
  ];

  @override
  Future<WorkflowAssetRef> resolveAssetByCode(String code) async {
    if (assetError != null) throw assetError!;
    return WorkflowAssetRef(
      id: 'a1',
      assetCode: 'AST-001',
      name: 'Generator',
      assetTypeId: assetTypeId,
      assetTypeName: assetTypeId.isEmpty ? '' : 'Transformer',
    );
  }

  @override
  Future<AgentWorkflow> createWorkflow({
    String? assetId,
    String? assetTypeId,
    required String objective,
  }) async {
    lastObjective = objective;
    lastAssetId = assetId;
    lastAssetTypeId = assetTypeId;
    return AgentWorkflow.fromJson({
      'id': 'w1',
      'asset_id': assetId,
      'asset_code': 'AST-001',
      'objective': objective,
      'status': 'PLANNING',
      'is_high_impact': false,
      'approval_status': 'NOT_APPLICABLE',
      'correlation_id': 'corr-1',
      'created_at': '2026-01-01T00:00:00Z',
    });
  }

  @override
  Future<List<AgentWorkflow>> getWorkflows() => throw UnimplementedError();

  @override
  Future<AgentWorkflow> getWorkflowById(String id) =>
      throw UnimplementedError();
}

Widget _harness(_FakeWorkflowsApi api) {
  final router = GoRouter(
    initialLocation: '/workflows/new',
    routes: [
      GoRoute(
        path: '/workflows/new',
        builder: (context, state) => const InitiateWorkflowScreen(),
      ),
      GoRoute(
        path: '/workflows/:id',
        builder: (context, state) =>
            Scaffold(body: Text('workflow ${state.pathParameters['id']}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [workflowsApiProvider.overrideWith((ref) => api)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets(
    'finds the asset by code before asking for an objective (FR-067)',
    (tester) async {
      final api = _FakeWorkflowsApi();
      await tester.pumpWidget(_harness(api));

      expect(find.text('Objective'), findsNothing);

      await tester.enterText(find.byType(TextFormField).first, 'AST-001');
      await tester.tap(find.widgetWithText(FilledButton, 'Find asset'));
      await tester.pumpAndSettle();

      expect(find.text('Generator'), findsOneWidget);
      expect(find.text('AST-001'), findsOneWidget);
      expect(find.text('Objective'), findsOneWidget);
    },
  );

  testWidgets('shows a message when the asset code doesn\'t resolve', (
    tester,
  ) async {
    final api = _FakeWorkflowsApi(
      assetError: ApiException(statusCode: 404, message: 'Asset not found.'),
    );
    await tester.pumpWidget(_harness(api));

    await tester.enterText(find.byType(TextFormField).first, 'AST-999');
    await tester.tap(find.widgetWithText(FilledButton, 'Find asset'));
    await tester.pumpAndSettle();

    expect(find.text('Asset not found.'), findsOneWidget);
  });

  testWidgets('requires an objective before submitting', (tester) async {
    final api = _FakeWorkflowsApi();
    await tester.pumpWidget(_harness(api));

    await tester.enterText(find.byType(TextFormField).first, 'AST-001');
    await tester.tap(find.widgetWithText(FilledButton, 'Find asset'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Request Evaluation'));
    await tester.pump();

    expect(find.text('State what the agent should evaluate'), findsOneWidget);
    expect(api.lastObjective, isNull);
  });

  testWidgets(
    'submits the objective and navigates to the workflow status screen',
    (tester) async {
      final api = _FakeWorkflowsApi();
      await tester.pumpWidget(_harness(api));

      await tester.enterText(find.byType(TextFormField).first, 'AST-001');
      await tester.tap(find.widgetWithText(FilledButton, 'Find asset'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Objective'),
        'Recommend repair or replace.',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Request Evaluation'));
      await tester.pumpAndSettle();

      expect(api.lastObjective, 'Recommend repair or replace.');
      expect(api.lastAssetId, 'a1');
      expect(api.lastAssetTypeId, isNull);
      expect(find.text('workflow w1'), findsOneWidget);
    },
  );

  testWidgets('asset type is picked by category before the objective', (
    tester,
  ) async {
    final api = _FakeWorkflowsApi();
    await tester.pumpWidget(_harness(api));

    await tester.tap(find.text('Asset type'));
    await tester.pumpAndSettle();

    expect(find.text('Select a category first'), findsOneWidget);
    expect(find.text('Objective'), findsNothing);

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    // Each category appears once even though "Power" has two types.
    expect(find.text('Power').last, findsOneWidget);
    await tester.tap(find.text('Power').last);
    await tester.pumpAndSettle();

    // Only the chosen category's types are offered.
    await tester.tap(find.widgetWithText(InputDecorator, 'Asset type'));
    await tester.pumpAndSettle();
    expect(find.text('Transformer'), findsWidgets);
    expect(find.text('Laptop'), findsNothing);
    await tester.tap(find.text('Transformer').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('every active Transformer asset'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Objective'),
      'Which transformers need replacing?',
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Request Evaluation'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Request Evaluation'));
    await tester.pumpAndSettle();

    expect(api.lastAssetTypeId, 't2');
    expect(api.lastAssetId, isNull);
    expect(find.text('workflow w1'), findsOneWidget);
  });

  testWidgets('changing the category clears the chosen asset type', (
    tester,
  ) async {
    final api = _FakeWorkflowsApi();
    await tester.pumpWidget(_harness(api));

    await tester.tap(find.text('Asset type'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Power').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InputDecorator, 'Asset type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generator').last);
    await tester.pumpAndSettle();
    expect(find.text('Objective'), findsOneWidget);

    await tester.tap(find.text('Power'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('IT equipment').last);
    await tester.pumpAndSettle();

    expect(find.text('Generator'), findsNothing);
    expect(find.text('Objective'), findsNothing);
  });

  group('a chosen asset with a known type', () {
    Future<_FakeWorkflowsApi> chooseAsset(WidgetTester tester) async {
      final api = _FakeWorkflowsApi(assetTypeId: 't2');
      await tester.pumpWidget(_harness(api));
      await tester.enterText(find.byType(TextFormField).first, 'AST-001');
      await tester.tap(find.widgetWithText(FilledButton, 'Find asset'));
      await tester.pumpAndSettle();
      return api;
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Objective'),
        'Recommend repair or replace.',
      );
      final button = find.widgetWithText(FilledButton, 'Request Evaluation');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('shows its asset type and category automatically', (
      tester,
    ) async {
      await chooseAsset(tester);

      expect(find.text('Transformer'), findsOneWidget);
      expect(find.text('Power'), findsOneWidget);
      expect(find.text('Just this asset'), findsOneWidget);
      expect(find.text('All Transformer assets'), findsOneWidget);
    });

    testWidgets('evaluates just the asset by default', (tester) async {
      final api = await chooseAsset(tester);
      await submit(tester);

      expect(api.lastAssetId, 'a1');
      expect(api.lastAssetTypeId, isNull);
    });

    testWidgets('can widen to the entire asset type', (tester) async {
      final api = await chooseAsset(tester);

      await tester.tap(find.text('All Transformer assets'));
      await tester.pumpAndSettle();
      await submit(tester);

      expect(api.lastAssetTypeId, 't2');
      expect(api.lastAssetId, isNull);
      expect(find.text('workflow w1'), findsOneWidget);
    });
  });
}
