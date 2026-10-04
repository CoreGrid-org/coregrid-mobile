import 'package:coregrid_mobile/features/transfers/models/transfer_response.dart';
import 'package:coregrid_mobile/features/transfers/screens/transfer_detail_screen.dart';
import 'package:coregrid_mobile/features/transfers/transfers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({
  String status = 'APPROVED',
  String? rejectionReason,
}) => {
  'id': 't1',
  'asset_id': 'a1',
  'asset_code': 'AST-0001',
  'asset_name': 'Portable Ultrasound Scanner',
  // Long enough to overflow a single line — this used to break layout.
  'from_department_name': 'Radiology and Diagnostic Imaging',
  'from_location_name': 'Main Building, Floor 2, Room 214',
  'to_department_name': 'Emergency Department',
  'to_location_name': 'East Wing Resuscitation Bay',
  'initiated_by_user_email': 'inventory.officer.long@hospital.example.org',
  'status': status,
  'requested_at': '2026-10-01T08:00:00Z',
  'rejection_reason': rejectionReason,
};

class _Api extends Fake implements TransfersApi {
  _Api(this.json);

  final Map<String, dynamic> json;

  @override
  Future<TransferResponse> getById(String transferId) async =>
      TransferResponse.fromJson(json);
}

Future<void> _pump(WidgetTester tester, Map<String, dynamic> json) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [transfersApiProvider.overrideWith((ref) => _Api(json))],
      child: const MaterialApp(home: TransferDetailScreen(transferId: 't1')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('loads a transfer with long department and location names', (
    tester,
  ) async {
    await _pump(tester, _json());

    expect(tester.takeException(), isNull);
    expect(find.text('Portable Ultrasound Scanner'), findsOneWidget);
    expect(
      find.text(
        'Radiology and Diagnostic Imaging · Main Building, Floor 2, '
        'Room 214',
      ),
      findsOneWidget,
    );
    expect(
      find.text('inventory.officer.long@hospital.example.org'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Confirm Receipt via Scan'),
      200,
    );
    expect(find.text('Confirm Receipt via Scan'), findsOneWidget);
  });

  testWidgets('a rejected transfer shows why and offers no receipt action', (
    tester,
  ) async {
    await _pump(
      tester,
      _json(status: 'REJECTED', rejectionReason: 'Destination is full.'),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Destination is full.'), findsOneWidget);
    expect(find.text('Confirm Receipt via Scan'), findsNothing);
  });
}
