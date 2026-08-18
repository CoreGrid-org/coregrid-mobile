import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    ],
  );
});
