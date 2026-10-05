import 'package:coregrid_mobile/features/assets/models/asset/asset_detail.dart';
import 'package:coregrid_mobile/features/verification/models/campaign_scope_assets.dart';
import 'package:coregrid_mobile/features/verification/models/verification_campaign.dart';
import 'package:coregrid_mobile/features/verification/models/verification_location.dart';
import 'package:coregrid_mobile/features/verification/models/verification_task.dart';
import 'package:coregrid_mobile/features/verification/screens/campaign_detail_screen.dart';
import 'package:coregrid_mobile/features/verification/screens/verification_task_list_screen.dart';
import 'package:coregrid_mobile/features/verification/verification_api.dart';
import 'package:coregrid_mobile/features/verification/verify_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _campaignJson = {
  'id': 'c1',
  'name': 'Q3 Ward Equipment Audit',
  'period_start': '2026-09-01',
  'period_end': '2026-09-30',
  'scope_department_id': 'd1',
  'scope_department_name': 'Radiology',
  'scope_asset_type_id': 't1',
  'scope_asset_type_name': 'Ultrasound Scanner',
  'status': 'Active',
  'task_count': 4,
  'completed_task_count': 3,
  'open_discrepancy_count': 1,
};

VerificationTask _task(
  String id, {
  String campaignId = 'c1',
  String status = 'Pending',
}) => VerificationTask.fromJson({
  'id': id,
  'campaign_id': campaignId,
  'campaign_name': 'Q3 Ward Equipment Audit',
  'asset_id': 'a-$id',
  'asset_code': 'AST-$id',
  'asset_name': 'Ultrasound',
  'due_date': '2099-01-01',
  'status': status,
  if (status == 'Completed') 'completed_at': '2026-09-10T09:00:00Z',
});

AssetDetail _asset(
  String id, {
  String type = 'Ultrasound Scanner',
  String department = 'Radiology',
  String location = 'Ward 3',
}) => AssetDetail.fromJson({
  'id': id,
  'asset_code': 'AST-${id.replaceFirst('a-', '')}',
  'name': 'Ultrasound',
  'asset_type_name': type,
  'department_name': department,
  'location_name': location,
});

class _Api extends Fake implements VerificationApi {
  @override
  Future<List<VerificationTask>> getTasks({
    bool mine = true,
    bool onlyPending = false,
  }) async => [
    _task('1'),
    _task('2', campaignId: 'other'),
    _task('3', status: 'Completed'),
  ];

  @override
  Future<List<VerificationCampaign>> getCampaigns() async => [
    VerificationCampaign.fromJson(_campaignJson),
  ];

  @override
  Future<VerificationCampaign> getCampaign(String id) async =>
      VerificationCampaign.fromJson(_campaignJson);

  @override
  Future<List<VerificationLocation>> getLocations() async => const [];

  @override
  Future<CampaignScopeAssets> getCampaignScopeAssets(
    VerificationCampaign campaign, {
    int maxPages = 10,
  }) async => CampaignScopeAssets(
    assets: [
      _asset('a-1', location: 'Ward 3'),
      _asset('a-3'),
    ],
  );
}

Widget _harness(Widget home) => ProviderScope(
  overrides: [verificationApiProvider.overrideWith((ref) => _Api())],
  child: MaterialApp(home: home),
);

void main() {
  test('campaign model derives progress and scope', () {
    final c = VerificationCampaign.fromJson(_campaignJson);
    expect(c.progress, 0.75);
    expect(c.scopeSummary, 'Radiology · Ultrasound Scanner');
    expect(c.status, CampaignStatus.active);
  });

  testWidgets('Campaigns segment lists campaigns with progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(const VerificationTaskListScreen(showCampaigns: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Q3 Ward Equipment Audit'), findsOneWidget);
    expect(find.text('3 of 4 verified'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('1 assigned to you'), findsOneWidget);
    expect(find.text('1 open discrepancy'), findsOneWidget);
  });

  testWidgets('campaign detail is read-only and shows only my tasks in it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(const CampaignDetailScreen(campaignId: 'c1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Q3 Ward Equipment Audit'), findsOneWidget);
    expect(find.textContaining('AST-1'), findsOneWidget);
    expect(find.textContaining('AST-2'), findsNothing);
    // No management actions on mobile (SRS §3.4).
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets(
    'campaign detail is a checklist: to verify, with scan, and done',
    (tester) async {
      await tester.pumpWidget(
        _harness(const CampaignDetailScreen(campaignId: 'c1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your assets · 1 of 2 verified'), findsOneWidget);
      expect(find.text('To verify · 1'), findsOneWidget);
      expect(find.text('Verified · 1'), findsOneWidget);
      // Only the still-to-verify row carries its own scan button.
      expect(find.byTooltip('Scan AST-1'), findsOneWidget);
      expect(find.byTooltip('Scan AST-3'), findsNothing);
      expect(find.text('Scan to verify'), findsOneWidget);
    },
  );

  testWidgets('campaign detail says what to scan and where to find it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(const CampaignDetailScreen(campaignId: 'c1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('What to scan'), findsOneWidget);
    expect(find.text('Asset type'), findsOneWidget);
    expect(find.text('Department'), findsOneWidget);
    // To-verify rows are grouped by registered location and show the type.
    expect(find.text('Ward 3 · 1'), findsOneWidget);
    expect(
      find.textContaining('Ultrasound Scanner ·'),
      findsAtLeastNWidgets(1),
    );
  });

  group('classifyCampaignScan', () {
    final campaign = VerificationCampaign.fromJson(_campaignJson);
    final myTasks = [
      _task('1'),
      _task('2', campaignId: 'other'),
      _task('3', status: 'Completed'),
    ];
    final scope = CampaignScopeAssets(
      assets: [_asset('a-1'), _asset('a-3'), _asset('a-9')],
    );

    CampaignScanResult classify(AssetDetail asset, {CampaignScopeAssets? s}) =>
        classifyCampaignScan(
          campaign: campaign,
          asset: asset,
          myTasks: myTasks,
          scopeAssets: s,
        );

    test('my pending task here → verify it', () {
      final r = classify(_asset('a-1'), s: scope);
      expect(r, isA<CampaignScanToVerify>());
      expect((r as CampaignScanToVerify).task.id, '1');
    });

    test('my completed task here → already verified', () {
      expect(
        classify(_asset('a-3'), s: scope),
        isA<CampaignScanAlreadyVerified>(),
      );
    });

    test('my task in another campaign → points there', () {
      final r = classify(_asset('a-2', type: 'Laptop'), s: scope);
      expect(r, isA<CampaignScanOtherCampaign>());
      expect((r as CampaignScanOtherCampaign).task.campaignId, 'other');
    });

    test('in scope but not assigned to me', () {
      expect(classify(_asset('a-9'), s: scope), isA<CampaignScanNotAssigned>());
    });

    test('outside the scope', () {
      expect(
        classify(_asset('a-7', type: 'Laptop'), s: scope),
        isA<CampaignScanOutOfScope>(),
      );
    });

    test('falls back to matching scope by name when the list is partial', () {
      final partial = CampaignScopeAssets(assets: const [], complete: false);
      expect(
        classify(_asset('a-8'), s: partial),
        isA<CampaignScanNotAssigned>(),
      );
      expect(
        classify(_asset('a-8', type: 'Laptop')),
        isA<CampaignScanOutOfScope>(),
      );
    });
  });
}
