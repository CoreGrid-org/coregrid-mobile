import 'package:coregrid_mobile/features/maintenance/maintenance_api.dart';
import 'package:coregrid_mobile/features/maintenance/models/fault_report.dart';
import 'package:coregrid_mobile/features/maintenance/models/maintenance_filter.dart';
import 'package:coregrid_mobile/features/maintenance/screens/maintenance_records_view.dart';
import 'package:coregrid_mobile/shared/auth/me_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FaultReport _r(int i, String status) => FaultReport(
  id: 'm$i',
  assetId: 'a$i',
  assetCode: 'AST-00$i',
  description: 'Record $i',
  observedCondition: 'FAIR',
  status: status,
  reportedAt: DateTime(2026, 9, i),
);

class _Api extends Fake implements MaintenanceApi {
  final calls = <(MaintenanceFilter, int)>[];

  @override
  Future<MaintenancePage> listRecords(
    MaintenanceFilter filter, {
    int page = 1,
    int pageSize = MaintenanceFilter.pageSize,
  }) async {
    calls.add((filter, page));
    return MaintenancePage(
      items: [_r(page, filter.status?.apiValue ?? 'REQUESTED')],
      totalCount: 2,
      page: page,
      totalPages: 2,
    );
  }
}

void main() {
  test('filter maps to the API\'s camelCase query parameters', () {
    final filter = const MaintenanceFilter(sort: MaintenanceSort.priority)
        .copyWith(
          status: () => MaintenanceStatus.inProgress,
          priority: () => MaintenancePriority.high,
          assigneeId: () => 'u1',
          asset: () => (id: 'a1', code: 'AST-1'),
          department: () => (id: 'd1', name: 'Fleet'),
          dateRange: () =>
              (from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 30)),
        );
    expect(filter.toQueryParameters(page: 2, pageSize: 20), {
      'status': 'IN_PROGRESS',
      'priority': 'HIGH',
      'departmentId': 'd1',
      'assetId': 'a1',
      'assigneeId': 'u1',
      'dateFrom': '2026-09-01',
      'dateTo': '2026-09-30',
      'sortBy': 'priority',
      'sortDirection': 'desc',
      'page': 2,
      'pageSize': 20,
    });
    expect(filter.activeCount, 6);
    expect(filter.copyWith(status: () => null).status, isNull);
  });

  test('status helpers recognise the API\'s IN_PROGRESS as active', () {
    final underWay = _r(1, 'IN_PROGRESS');
    expect(underWay.isUnderWay, isTrue);
    expect(underWay.isInProgress, isTrue);
    expect(_r(1, 'APPROVED').isApproved, isTrue);
    expect(_r(1, 'CANCELLED').isCancelled, isTrue);
    expect(_r(1, 'COMPLETED').isInProgress, isFalse);
  });

  testWidgets('lists records, loads more, filters by status', (tester) async {
    final api = _Api();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          maintenanceApiProvider.overrideWithValue(api),
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
        child: const MaterialApp(
          home: Scaffold(body: MaintenanceRecordsView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 records'), findsOneWidget);
    expect(find.textContaining('Record 1'), findsOneWidget);

    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Record 2'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Approved'));
    await tester.pumpAndSettle();
    expect(api.calls.last.$1.status, MaintenanceStatus.approved);
    expect(api.calls.last.$2, 1);

    await tester.tap(find.widgetWithText(FilterChip, 'Assigned to me'));
    await tester.pumpAndSettle();
    expect(api.calls.last.$1.assigneeId, 'me-1');
  });
}
