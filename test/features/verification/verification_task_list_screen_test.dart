import 'package:coregrid_mobile/features/verification/models/discrepancy.dart';
import 'package:coregrid_mobile/features/verification/models/verification_location.dart';
import 'package:coregrid_mobile/features/verification/models/verification_task.dart';
import 'package:coregrid_mobile/features/verification/screens/verification_task_list_screen.dart';
import 'package:coregrid_mobile/features/verification/verification_api.dart';
import 'package:coregrid_mobile/shared/api/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVerificationApi implements VerificationApi {
  _FakeVerificationApi({this.tasks = const [], this.error});

  final List<VerificationTask> tasks;
  final Object? error;

  @override
  Future<List<VerificationTask>> getTasks({
    bool mine = true,
    bool onlyPending = false,
  }) async {
    if (error != null) throw error!;
    return tasks;
  }

  @override
  Future<VerificationTask> completeTask({
    required String taskId,
    required bool assertedPresent,
    String? assertedLocationId,
    String? assertedCondition,
  }) => throw UnimplementedError();

  @override
  Future<List<VerificationLocation>> getLocations() async => const [];

  @override
  Future<String> uploadPhoto({
    required List<int> bytes,
    required String fileName,
  }) => throw UnimplementedError();

  @override
  Future<Discrepancy> raiseDiscrepancy({
    required String taskId,
    required DiscrepancyType type,
    required String description,
    String? photoUrl,
  }) => throw UnimplementedError();
}

VerificationTask _task({String status = 'Pending', bool overdue = false}) {
  return VerificationTask.fromJson({
    'id': 't1',
    'campaign_id': 'c1',
    'campaign_name': 'Q3 Audit',
    'asset_id': 'a1',
    'asset_code': 'AST-001',
    'asset_name': 'Generator',
    'due_date': overdue ? '2020-01-01' : '2099-01-01',
    'status': status,
  });
}

Widget _harness(_FakeVerificationApi api) {
  return ProviderScope(
    overrides: [verificationApiProvider.overrideWith((ref) => api)],
    child: const MaterialApp(home: VerificationTaskListScreen()),
  );
}

void main() {
  testWidgets('shows the empty state when there are no tasks (FR-058)', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_FakeVerificationApi()));
    await tester.pumpAndSettle();

    expect(
      find.text('No verification tasks assigned to you.'),
      findsOneWidget,
    );
  });

  testWidgets('lists tasks with their campaign and due date (FR-058)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(_FakeVerificationApi(tasks: [_task()])),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('AST-001'), findsOneWidget);
    expect(find.textContaining('Q3 Audit'), findsOneWidget);
  });

  testWidgets('flags an overdue pending task', (tester) async {
    await tester.pumpWidget(
      _harness(_FakeVerificationApi(tasks: [_task(overdue: true)])),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('(overdue)'), findsOneWidget);
  });

  testWidgets('shows a retryable error state on failure', (tester) async {
    await tester.pumpWidget(
      _harness(
        _FakeVerificationApi(
          error: ApiException(statusCode: 500, message: 'Server error.'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Server error.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
  });
}
