import 'package:coregrid_mobile/features/assets/mock_assets_api.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_condition.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_verification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock verification returns success when observations match', () async {
    final result = await MockAssetsApi().verifyAsset(
      assetId: 'asset-12345',
      request: const AssetVerificationRequest(
        present: true,
        location: 'Plant A - Section 3',
        condition: AssetCondition.good,
      ),
    );

    expect(result.discrepancyRaised, isFalse);
    expect(result.message, contains('successfully'));
  });

  test('mock verification returns discrepancy for mismatched observations', () async {
    final result = await MockAssetsApi().verifyAsset(
      assetId: 'asset-12345',
      request: const AssetVerificationRequest(
        present: false,
        location: 'Plant B',
        condition: AssetCondition.poor,
      ),
    );

    expect(result.discrepancyRaised, isTrue);
    expect(result.message, contains('discrepancy'));
  });
}
