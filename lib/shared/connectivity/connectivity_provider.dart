import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has a network connection — drives the
/// app-wide offline banner and the sign-in offline message
/// (`mobile-specification.md` §2, `connectivity_plus`).
///
/// This only knows whether a network interface is up, not whether CoreGrid
/// answers — a request that still fails falls through to [ErrorView]'s
/// offline state as before. If the platform check itself fails (e.g. no
/// plugin in widget tests), it assumes online rather than blocking the user.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool? last;
  try {
    last = _hasNetwork(await connectivity.checkConnectivity());
    yield last;
    await for (final results in connectivity.onConnectivityChanged) {
      final online = _hasNetwork(results);
      if (online != last) yield last = online;
    }
  } catch (_) {
    if (last == null) yield true;
  }
});

bool _hasNetwork(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);
