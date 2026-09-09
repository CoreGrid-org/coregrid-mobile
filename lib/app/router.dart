import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/assets/screens/asset/asset_detail_screen.dart';
import '../features/assets/screens/asset/asset_lookup_screen.dart';
import '../features/assets/screens/asset/asset_search_screen.dart';
import '../features/auth/screens/access_restricted_screen.dart';
import '../features/auth/screens/sign_in_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';

/// Route table mirrors the `lib/features/` layout one-to-one
/// (`doc/MOBILE-SPECIFICATION.md` §3.1/§3.3) — no route lives outside its
/// feature's folder. Each feature wires its own routes in here as it lands.
///
/// No auth-state redirect guard yet — with only three routes and one flow
/// (sign-in → sign out), navigation is driven directly by `SignInScreen`.
/// Add a `redirect` callback here once more protected routes exist to guard.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/sign-in',
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/access-restricted',
        builder: (context, state) =>
            AccessRestrictedScreen(role: state.extra as String? ?? ''),
      ),
      // features/assets/ — FR-025 manual code entry, the reachable entry point
      // to the detail screen until features/scan/ lands.
      GoRoute(
        path: '/assets',
        builder: (context, state) => const AssetLookupScreen(),
      ),
      GoRoute(
        path: '/assets/search',
        builder: (context, state) => const AssetSearchScreen(),
      ),
      // features/assets/ — FR-020/§4.4. Resolves the asset by id; reached from
      // the lookup screen above, or a scan once features/scan/ exists.
      GoRoute(
        path: '/assets/:id',
        builder: (context, state) =>
            AssetDetailScreen(assetId: state.pathParameters['id']!),
      ),
    ],
  );
});
