import 'package:coregrid_mobile/features/workflows/models/agent_workflow.dart';
import 'package:coregrid_mobile/features/workflows/models/workflow_asset_ref.dart';
import 'package:coregrid_mobile/features/workflows/screens/initiate_workflow_screen.dart';
import 'package:coregrid_mobile/features/workflows/workflows_api.dart';
import 'package:coregrid_mobile/shared/api/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeWorkflowsApi implements WorkflowsApi {
  _FakeWorkflowsApi({this.assetError});

  final Object? assetError;
  String? lastObjective;

  @override
  Future<WorkflowAssetRef> resolveAssetByCode(String code) async {
    if (assetError != null) throw assetError!;
    return const WorkflowAssetRef(id: 'a1', assetCode: 'AST-001', name: 'Generator');
  }

  @override
  Future<AgentWorkflow> createWorkflow({
    required String assetId,
    required String objective,
  }) async {
    lastObjective = objective;
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
  Future<AgentWorkflow> getWorkflowById(String id) => throw UnimplementedError();
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
  testWidgets('finds the asset by code before asking for an objective (FR-067)', (
    tester,
  ) async {
    final api = _FakeWorkflowsApi();
    await tester.pumpWidget(_harness(api));

    expect(find.text('Objective'), findsNothing);

    await tester.enterText(find.byType(TextFormField).first, 'AST-001');
    await tester.tap(find.widgetWithText(FilledButton, 'Find asset'));
    await tester.pumpAndSettle();

    expect(find.textContaining('AST-001 — Generator'), findsOneWidget);
    expect(find.text('Objective'), findsOneWidget);
  });

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

  testWidgets('submits the objective and navigates to the workflow status screen', (
    tester,
  ) async {
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
    expect(find.text('workflow w1'), findsOneWidget);
  });
}
