import 'package:coregrid_mobile/features/maintenance/maintenance_api.dart';
import 'package:coregrid_mobile/features/maintenance/maintenance_providers.dart';
import 'package:coregrid_mobile/features/maintenance/models/fault_report.dart';
import 'package:coregrid_mobile/features/maintenance/screens/fault_detail_screen.dart';
import 'package:coregrid_mobile/shared/auth/me_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FaultReport _record({String status = 'IN_PROGRESS', String? assigneeId}) =>
    FaultReport(
      id: 'fault-1',
      assetId: 'asset-1',
      assetCode: 'AST-001',
      description: 'Hydraulic oil is leaking near the rear wheel.',
      observedCondition: 'POOR',
      status: status,
      reportedAt: DateTime(2026, 9, 25),
      reportedByName: 'Alex Officer',
      reportedByEmail: 'alex@example.com',
      assigneeId: assigneeId,
      assigneeEmail: assigneeId == 'me-1' ? 'sam@example.com' : null,
    );

class _Api extends Fake implements MaintenanceApi {
  _Api(this.record);

  FaultReport record;
  String? startedId;

  @override
  Future<FaultReport> getRecord(String id) async => record;

  @override
  Future<FaultReport> startWork(String id) async {
    startedId = id;
    return record = _record(status: 'IN_PROGRESS', assigneeId: 'me-1');
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Api api, {
  bool officer = false,
  FaultReport? initial,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        maintenanceApiProvider.overrideWithValue(api),
        canManageMaintenanceProvider.overrideWithValue(officer),
        meProvider.overrideWith(
          (ref) async => const MeProfile(
            id: 'me-1',
            email: 'sam@example.com',
            givenName: 'Sam',
            familyName: 'Officer',
            role: 'InventoryOfficer',
            organizationName: 'Org',
          ),
        ),
      ],
      child: MaterialApp(
        home: FaultDetailScreen(id: 'fault-1', report: initial),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the selected fault report details', (tester) async {
    final report = _record();
    await _pump(tester, _Api(report), initial: report);

    expect(find.text('Fault report'), findsOneWidget);
    expect(find.text('AST-001'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(
      find.text('Hydraulic oil is leaking near the rear wheel.'),
      findsOneWidget,
    );
    expect(find.text('Poor'), findsOneWidget);
    expect(find.text('25 Sep 2026'), findsOneWidget);
    expect(find.text('Alex Officer'), findsOneWidget);
    expect(find.text('alex@example.com'), findsOneWidget);
    // Staff see no progress-update action.
    expect(find.text('Start work'), findsNothing);
  });

  testWidgets('loads the record by id when opened without a copy', (
    tester,
  ) async {
    await _pump(tester, _Api(_record(status: 'REQUESTED')));
    expect(find.text('Requested'), findsWidgets);
  });

  testWidgets('assigned officer starts APPROVED work (FR-037)', (tester) async {
    final api = _Api(_record(status: 'APPROVED', assigneeId: 'me-1'));
    await _pump(tester, api, officer: true);

    await tester.ensureVisible(find.text('Start work'));
    await tester.tap(find.text('Start work'));
    await tester.pumpAndSettle();
    // Confirm dialog.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Start work'),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.startedId, 'fault-1');
    expect(find.textContaining('Work under way'), findsOneWidget);
    expect(find.text('Start work'), findsNothing);
  });

  testWidgets('another officer cannot start work assigned elsewhere', (
    tester,
  ) async {
    await _pump(
      tester,
      _Api(_record(status: 'APPROVED', assigneeId: 'someone-else')),
      officer: true,
    );
    expect(find.text('Start work'), findsNothing);
    expect(find.textContaining('waiting for'), findsOneWidget);
  });
}
