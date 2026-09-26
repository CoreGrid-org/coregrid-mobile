import 'package:coregrid_mobile/features/maintenance/models/fault_report.dart';
import 'package:coregrid_mobile/features/maintenance/screens/fault_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the selected fault report details', (tester) async {
    final report = FaultReport(
      id: 'fault-1',
      assetId: 'asset-1',
      assetCode: 'AST-001',
      description: 'Hydraulic oil is leaking near the rear wheel.',
      observedCondition: 'POOR',
      status: 'IN_PROGRESS',
      reportedAt: DateTime(2026, 9, 25),
      reportedByName: 'Alex Officer',
      reportedByEmail: 'alex@example.com',
    );

    await tester.pumpWidget(
      MaterialApp(home: FaultDetailScreen(report: report)),
    );

    expect(find.text('Fault Details'), findsOneWidget);
    expect(find.text('AST-001'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(
      find.text('Hydraulic oil is leaking near the rear wheel.'),
      findsOneWidget,
    );
    expect(find.text('Poor'), findsOneWidget);
    expect(find.text('September 25, 2026'), findsOneWidget);
    expect(find.text('Alex Officer'), findsOneWidget);
    expect(find.text('alex@example.com'), findsOneWidget);
  });
}
