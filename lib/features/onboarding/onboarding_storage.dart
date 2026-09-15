import 'package:shared_preferences/shared_preferences.dart';

/// Whether the one-time onboarding intro has been shown — plain,
/// non-sensitive UI state, so `shared_preferences` rather than
/// `flutter_secure_storage` (that one's reserved for the refresh token,
/// SEC-ID-05/06 — see `shared/auth/token_storage.dart`).
class OnboardingStorage {
  static const _seenKey = 'onboarding_seen';

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }
}
