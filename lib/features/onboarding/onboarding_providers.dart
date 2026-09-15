import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_storage.dart';

final onboardingStorageProvider = Provider<OnboardingStorage>((ref) {
  return OnboardingStorage();
});

/// Whether the one-time intro has already been shown on this device —
/// `OnboardingScreen`'s route stays first in the router, but this lets it
/// redirect itself straight past to `/sign-in` on every later launch.
final onboardingSeenProvider = FutureProvider<bool>((ref) {
  return ref.watch(onboardingStorageProvider).hasSeenOnboarding();
});
