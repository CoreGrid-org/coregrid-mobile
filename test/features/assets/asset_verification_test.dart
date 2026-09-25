import 'package:coregrid_mobile/features/assets/assets_api.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_condition.dart';
import 'package:coregrid_mobile/features/assets/models/asset/asset_verification.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVerifiableAssetsApi implements VerifiableAssetsApi {
  @override
  Future<AssetVerificationResult> verifyAsset({
    required String assetId,
    required AssetVerificationRequest request,
  }) async {
    if (!request.present ||
        request.locationId != 'location-a' ||
        request.condition != AssetCondition.good) {
      return const AssetVerificationResult(
        discrepancyRaised: true,
        message: 'A discrepancy was raised for the asset.',
      );
    }
    return const AssetVerificationResult(
      discrepancyRaised: false,
      message: 'Asset verified successfully.',
    );
  }
}

void main() {
  test('mock verification returns success when observations match', () async {
    final result = await _FakeVerifiableAssetsApi().verifyAsset(
      assetId: 'asset-12345',
      request: const AssetVerificationRequest(
        present: true,
        locationId: 'location-a',
        condition: AssetCondition.good,
      ),
    );

    expect(result.discrepancyRaised, isFalse);
    expect(result.message, contains('successfully'));
  });

  test('mock verification returns discrepancy for mismatched observations', () async {
    final result = await _FakeVerifiableAssetsApi().verifyAsset(
      assetId: 'asset-12345',
      request: const AssetVerificationRequest(
        present: false,
        locationId: 'location-b',
        condition: AssetCondition.poor,
      ),
    );

    expect(result.discrepancyRaised, isTrue);
    expect(result.message, contains('discrepancy'));
  });
}
