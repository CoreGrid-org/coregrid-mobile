import 'package:coregrid_mobile/features/workflows/models/agent_workflow.dart';
import 'package:coregrid_mobile/features/workflows/models/workflow_asset_ref.dart';
import 'package:coregrid_mobile/features/workflows/screens/workflow_detail_screen.dart';
import 'package:coregrid_mobile/features/workflows/workflows_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({
  String status = 'COMPLETED_ADVISORY',
  String scope = 'ASSET',
  String? assetId = 'a1',
  String? recommendation = 'RETAIN',
  String? failureReason,
  Map<String, dynamic>? fleet,
}) => {
  'id': 'w1',
  'scope': scope,
  'asset_id': assetId,
  'asset_code': assetId == null ? '' : 'GEN-007',
  'asset_type_name': 'Diesel Generator',
  'category_name': 'Plant',
  'objective': 'Evaluate lifecycle action',
  'status': status,
  'recommendation': recommendation,
  'is_high_impact': status == 'AWAITING_APPROVAL',
  'approval_status': status == 'AWAITING_APPROVAL' ? 'PENDING' : 'NOT_REQUIRED',
  'revision_count': 0,
  'failure_reason': failureReason,
  'fleet': fleet,
  'correlation_id': 'c1',
  'created_at': '2026-10-04T08:00:00Z',
};

class _FakeWorkflowsApi implements WorkflowsApi {
  _FakeWorkflowsApi(this.workflow);

  final AgentWorkflow workflow;

  @override
  Future<AgentWorkflow> getWorkflowById(String id) async => workflow;

  @override
  Future<List<AgentWorkflow>> getWorkflows() => throw UnimplementedError();

  @override
  Future<AgentWorkflow> createWorkflow({
    required String assetId,
    required String objective,
  }) => throw UnimplementedError();

  @override
  Future<WorkflowAssetRef> resolveAssetByCode(String code) =>
      throw UnimplementedError();
}

Future<void> _pumpDetail(WidgetTester tester, AgentWorkflow workflow) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workflowsApiProvider.overrideWith((ref) => _FakeWorkflowsApi(workflow)),
      ],
      child: const MaterialApp(home: WorkflowDetailScreen(workflowId: 'w1')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AgentWorkflow status', () {
    test('running statuses are in progress, not finished', () {
      for (final status in ['PLANNING', 'ANALYZING', 'VALIDATING']) {
        final w = AgentWorkflow.fromJson(_json(status: status));
        expect(w.isInProgress, isTrue, reason: status);
        expect(w.isFinished, isFalse, reason: status);
      }
    });

    test('awaiting approval is neither running nor finished', () {
      final w = AgentWorkflow.fromJson(_json(status: 'AWAITING_APPROVAL'));
      expect(w.isAwaitingApproval, isTrue);
      expect(w.isInProgress, isFalse);
      expect(w.isFinished, isFalse);
    });

    test('FAILED_SAFE and REJECTED are stopped and finished', () {
      for (final status in ['FAILED_SAFE', 'REJECTED']) {
        final w = AgentWorkflow.fromJson(_json(status: status));
        expect(w.isStopped, isTrue, reason: status);
        expect(w.isFinished, isTrue, reason: status);
      }
    });

    test('an asset-type evaluation has no asset and is labelled by type', () {
      final w = AgentWorkflow.fromJson(
        _json(scope: 'ASSET_TYPE', assetId: null),
      );
      expect(w.isSingleAsset, isFalse);
      expect(w.targetLabel, 'Diesel Generator fleet');
    });

    test('a single asset takes its reason from the fleet result', () {
      final w = AgentWorkflow.fromJson(
        _json(
          fleet: {
            'asset_count': 1,
            'action_counts': {'RETAIN': 1},
            'pass_count': 1,
            'deferred_count': 0,
            'blocked_count': 0,
            'assets': [
              {
                'asset_code': 'GEN-007',
                'action': 'RETAIN',
                'verdict': 'PASS',
                'reason': 'No repair spend projected.',
              },
            ],
          },
        ),
      );
      expect(w.reason, 'No repair spend projected.');
    });
  });

  group('WorkflowDetailScreen', () {
    testWidgets('shows a completed recommendation with its reason', (
      tester,
    ) async {
      final workflow = AgentWorkflow.fromJson(
        _json(
          fleet: {
            'asset_count': 1,
            'action_counts': {'RETAIN': 1},
            'assets': [
              {
                'asset_code': 'GEN-007',
                'action': 'RETAIN',
                'verdict': 'PASS',
                'reason': 'No repair spend projected.',
              },
            ],
          },
        ),
      );
      await _pumpDetail(tester, workflow);

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Recommendation: Retain'), findsOneWidget);
      expect(find.text('No repair spend projected.'), findsOneWidget);
      expect(find.text('Open asset record'), findsOneWidget);
    });

    testWidgets('a safe stop explains why and offers no recommendation', (
      tester,
    ) async {
      final workflow = AgentWorkflow.fromJson(
        _json(
          status: 'FAILED_SAFE',
          recommendation: null,
          failureReason: 'Out of scope.',
        ),
      );
      await _pumpDetail(tester, workflow);

      expect(find.text('Stopped safely'), findsOneWidget);
      expect(find.text('No action will be taken'), findsOneWidget);
      expect(find.text('Out of scope.'), findsOneWidget);
    });

    testWidgets(
      'a fleet evaluation summarises the action mix and has no asset link',
      (tester) async {
        final workflow = AgentWorkflow.fromJson(
          _json(
            scope: 'ASSET_TYPE',
            assetId: null,
            recommendation: 'REPAIR',
            fleet: {
              'asset_count': 3,
              'action_counts': {'REPAIR': 2, 'RETAIN': 1},
              'deferred_count': 0,
              'assets': [],
            },
          ),
        );
        await _pumpDetail(tester, workflow);

        expect(find.text('Diesel Generator fleet · Plant'), findsOneWidget);
        expect(
          find.text('Across 3 assets: 2 repair, 1 retain.'),
          findsOneWidget,
        );
        expect(find.text('Open asset record'), findsNothing);
      },
    );

    testWidgets('a fleet evaluation lists each asset, problems first', (
      tester,
    ) async {
      final workflow = AgentWorkflow.fromJson(
        _json(
          scope: 'ASSET_TYPE',
          assetId: null,
          recommendation: 'REPAIR',
          fleet: {
            'asset_count': 2,
            'action_counts': {'REPAIR': 1, 'DISPOSE': 1},
            'assets': [
              {
                'asset_id': 'a1',
                'asset_code': 'GEN-001',
                'condition': 'FAIR',
                'action': 'REPAIR',
                'verdict': 'PASS',
                'reason': 'Repair is cheaper than replacement.',
              },
              {
                'asset_id': 'a2',
                'asset_code': 'GEN-002',
                'condition': 'UNSERVICEABLE',
                'action': 'DISPOSE',
                'verdict': 'FAIL',
                'reason': 'Disposal needs a write-off approval.',
              },
            ],
          },
        ),
      );
      await _pumpDetail(tester, workflow);

      expect(find.text('Asset by asset · 2'), findsOneWidget);
      expect(find.text('GEN-001 · Fair'), findsOneWidget);
      expect(find.text('Dispose'), findsOneWidget);
      expect(find.text('Disposal needs a write-off approval.'), findsOneWidget);
      // The asset policy didn't clear is listed first.
      expect(
        tester.getTopLeft(find.text('GEN-002 · Unserviceable')).dy,
        lessThan(tester.getTopLeft(find.text('GEN-001 · Fair')).dy),
      );
    });
  });
}
