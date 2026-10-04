import 'package:coregrid_mobile/features/workflows/models/agent_workflow.dart';
import 'package:coregrid_mobile/features/workflows/models/workflow_asset_ref.dart';
import 'package:coregrid_mobile/features/workflows/screens/workflow_list_screen.dart';
import 'package:coregrid_mobile/features/workflows/workflows_api.dart';
import 'package:coregrid_mobile/shared/auth/me_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AgentWorkflow _workflow(String id, String code, {required String by}) =>
    AgentWorkflow.fromJson({
      'id': id,
      'scope': 'ASSET',
      'asset_id': 'a-$id',
      'asset_code': code,
      'asset_type_name': 'Diesel Generator',
      'category_name': 'Plant',
      'objective': 'Evaluate lifecycle action',
      'status': 'COMPLETED_ADVISORY',
      'recommendation': 'RETAIN',
      'approval_status': 'NOT_REQUIRED',
      'correlation_id': 'c-$id',
      'initiated_by_user_id': by,
      'created_at': '2026-10-04T08:00:00Z',
    });

class _Api extends Fake implements WorkflowsApi {
  _Api(this.workflows);

  final List<AgentWorkflow> workflows;

  @override
  Future<List<AgentWorkflow>> getWorkflows() async => workflows;

  @override
  Future<WorkflowAssetRef> resolveAssetByCode(String code) =>
      throw UnimplementedError();
}

Future<void> _pump(WidgetTester tester, List<AgentWorkflow> workflows) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workflowsApiProvider.overrideWith((ref) => _Api(workflows)),
        meProvider.overrideWith(
          (ref) async => const MeProfile(
            id: 'me',
            email: 'officer@example.org',
            givenName: 'Ann',
            familyName: 'Officer',
            role: 'InventoryOfficer',
            organizationName: 'Org',
          ),
        ),
      ],
      child: const MaterialApp(home: WorkflowListScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on my own requests, with everyone\'s one tap away', (
    tester,
  ) async {
    await _pump(tester, [
      _workflow('1', 'GEN-MINE', by: 'me'),
      _workflow('2', 'GEN-THEIRS', by: 'someone-else'),
    ]);

    expect(find.textContaining('GEN-MINE'), findsOneWidget);
    expect(find.textContaining('GEN-THEIRS'), findsNothing);

    await tester.tap(find.text('Everyone'));
    await tester.pumpAndSettle();

    expect(find.textContaining('GEN-MINE'), findsOneWidget);
    expect(find.textContaining('GEN-THEIRS'), findsOneWidget);
  });

  testWidgets('with none of my own, offers to show everyone\'s', (
    tester,
  ) async {
    await _pump(tester, [_workflow('2', 'GEN-THEIRS', by: 'someone-else')]);

    expect(find.text('You haven\'t requested any evaluations'), findsOneWidget);
    await tester.tap(find.text('See everyone\'s'));
    await tester.pumpAndSettle();

    expect(find.textContaining('GEN-THEIRS'), findsOneWidget);
  });
}
