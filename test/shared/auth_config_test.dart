import 'package:coregrid_mobile/shared/auth/auth_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no recovery URL without THUNDERID_APPLICATION_ID', () {
    // Tests run without --dart-define, so the recovery page isn't configured
    // and the entry points fall back to explaining the alternatives.
    expect(AuthConfig.thunderIdApplicationId, isEmpty);
    expect(AuthConfig.passwordRecoveryUrl, isNull);
  });
}
