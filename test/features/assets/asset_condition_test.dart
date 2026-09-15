import 'package:coregrid_mobile/features/assets/models/asset/asset_condition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssetCondition', () {
    test('covers exactly the SRS five-point scale', () {
      expect(
        AssetCondition.values.map((c) => c.label),
        ['New', 'Good', 'Fair', 'Poor', 'Unserviceable'],
      );
      expect(
        AssetCondition.values.map((c) => c.apiValue),
        ['NEW', 'GOOD', 'FAIR', 'POOR', 'UNSERVICEABLE'],
      );
    });

    test('tryParse is case-insensitive and trims', () {
      expect(AssetCondition.tryParse('GOOD'), AssetCondition.good);
      expect(AssetCondition.tryParse('  fair '), AssetCondition.fair);
      expect(AssetCondition.tryParse('Unserviceable'), AssetCondition.unserviceable);
    });

    test('tryParse returns null for unknown / empty input', () {
      expect(AssetCondition.tryParse(null), isNull);
      expect(AssetCondition.tryParse(''), isNull);
      expect(AssetCondition.tryParse('BROKEN'), isNull);
    });
  });
}
