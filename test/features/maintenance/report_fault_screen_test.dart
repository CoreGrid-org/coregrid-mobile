import 'package:coregrid_mobile/features/assets/assets_api.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_condition.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_detail.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_history_entry.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_maintenance_history.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_search.dart';
import 'package:coregrid_mobile/features/maintenance/maintenance_api.dart';
import 'package:coregrid_mobile/features/maintenance/maintenance_providers.dart';
import 'package:coregrid_mobile/features/maintenance/models/fault_report.dart';
import 'package:coregrid_mobile/features/maintenance/screens/report_fault_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMaintenanceApi implements MaintenanceApi {
  String? submittedAssetId;
  String? submittedDescription;
  String? submittedCondition;

  @override
  Future<List<FaultReport>> getMyReports() async => [
    FaultReport(
      id: 'fault-1',
      assetId: 'asset-1',
      assetCode: 'AST-001',
      description: 'Broken wheel',
      observedCondition: 'POOR',
      status: 'Open',
      reportedAt: DateTime(2026, 9, 25),
    ),
  ];

  @override
  Future<FaultReport> reportFault({
    required String assetId,
    required String description,
    required String observedCondition,
    String? photoUrl,
  }) async {
    submittedAssetId = assetId;
    submittedDescription = description;
    submittedCondition = observedCondition;
    return FaultReport(
      id: 'fault-1',
      assetId: assetId,
      assetCode: 'AST-001',
      description: description,
      observedCondition: observedCondition,
      status: 'Open',
      reportedAt: DateTime.now(),
    );
  }

  @override
  Future<String> uploadPhoto({
    required List<int> bytes,
    required String fileName,
  }) async => 'https://example.com/photo.jpg';
}

void main() {
  testWidgets('renders ReportFaultScreen with prefilled asset', (tester) async {
    final fakeApi = _FakeMaintenanceApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [maintenanceApiProvider.overrideWithValue(fakeApi)],
        child: const MaterialApp(
          home: ReportFaultScreen(assetId: 'asset-1', assetCode: 'AST-001'),
        ),
      ),
    );

    expect(find.text('Report Asset Fault'), findsOneWidget);
    expect(find.text('AST-001'), findsOneWidget);
    expect(find.text('Observed Condition'), findsOneWidget);
    expect(find.text('Fault Description'), findsOneWidget);
  });

  testWidgets('submits fault report successfully with prefilled asset', (
    tester,
  ) async {
    final fakeApi = _FakeMaintenanceApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [maintenanceApiProvider.overrideWithValue(fakeApi)],
        child: const MaterialApp(
          home: ReportFaultScreen(assetId: 'asset-1', assetCode: 'AST-001'),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Describe the issue or defect…'),
      'Leaking hydraulic oil on side',
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Submit Fault Report'));
    await tester.tap(find.text('Submit Fault Report'));
    await tester.pumpAndSettle();

    expect(fakeApi.submittedAssetId, 'asset-1');
    expect(fakeApi.submittedDescription, 'Leaking hydraulic oil on side');
  });

  testWidgets('picks an asset from department list and submits', (
    tester,
  ) async {
    final fakeApi = _FakeMaintenanceApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          maintenanceApiProvider.overrideWithValue(fakeApi),
          faultAssetSearchProvider.overrideWith(
            (ref, search) async => [
              AssetDetail.fromJson({
                'id': 'asset-99',
                'asset_code': 'AST-099',
                'name': 'Office Laptop',
                'asset_type_name': 'IT Hardware',
                'department_name': 'Engineering',
                'location_name': 'Floor 2',
                'status': 'ACTIVE',
                'condition': 'GOOD',
                'acquisition_date': '2023-01-01',
                'attributes': [],
              }),
            ],
          ),
        ],
        child: const MaterialApp(home: ReportFaultScreen()),
      ),
    );

    expect(find.text('Select Asset from Department…'), findsOneWidget);
    await tester.tap(find.text('Select Asset from Department…'));
    await tester.pumpAndSettle();

    expect(find.text('Select Department Asset'), findsOneWidget);
    expect(find.text('AST-099'), findsOneWidget);

    await tester.tap(find.text('AST-099'));
    await tester.pumpAndSettle();

    expect(find.text('AST-099'), findsOneWidget);
    expect(find.text('Office Laptop'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Describe the issue or defect…'),
      'Screen flickering',
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Submit Fault Report'));
    await tester.tap(find.text('Submit Fault Report'));
    await tester.pumpAndSettle();

    expect(fakeApi.submittedAssetId, 'asset-99');
    expect(fakeApi.submittedDescription, 'Screen flickering');
  });

  test('FaultReport parses and maps status correctly', () {
    final report1 = FaultReport.fromJson({
      'id': 'f-1',
      'asset_code': 'AST-1',
      'description': 'Issue 1',
      'status': 'Approved',
    });
    expect(report1.statusLabel, 'Approved');

    final report2 = FaultReport.fromJson({
      'id': 'f-2',
      'asset_code': 'AST-2',
      'description': 'Issue 2',
      'status': 1,
    });
    expect(report2.statusLabel, 'Approved');

    final report3 = FaultReport.fromJson({
      'id': 'f-3',
      'asset_code': 'AST-3',
      'description': 'Issue 3',
      'status': 'IN_PROGRESS',
    });
    expect(report3.statusLabel, 'In Progress');

    final report4 = FaultReport.fromJson({
      'id': 'f-4',
      'asset_code': 'AST-4',
      'description': 'Issue 4',
      'status': 'RESOLVED',
    });
    expect(report4.statusLabel, 'Resolved');
  });
}
