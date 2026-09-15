import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/assets/screens/asset/asset_detail_screen.dart';
import '../features/assets/screens/asset/asset_lookup_screen.dart';
import '../features/assets/screens/asset/asset_search_screen.dart';
import '../features/auth/screens/access_restricted_screen.dart';
import '../features/auth/screens/sign_in_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/verification/screens/raise_discrepancy_screen.dart';
import '../features/verification/screens/verification_task_detail_screen.dart';
import '../features/verification/screens/verification_task_list_screen.dart';
import '../features/workflows/screens/initiate_workflow_screen.dart';
import '../features/workflows/screens/workflow_detail_screen.dart';
import '../features/workflows/screens/workflow_list_screen.dart';
import '../shared/auth/auth_controller.dart';
import '../shared/auth/auth_state.dart';

/// `features/verification/` and `features/workflows/` are Inventory Officer
/// only on mobile (FR-058/FR-059/FR-061/FR-067/FR-069/FR-076 — SRS scope
/// change v1.5; Staff has no role in either). Both dashboards never link to
/// these routes for a Staff session, but a direct navigation is still
/// guarded here per §3.3's `redirect`-based role gate.
const _officerOnlyPrefixes = ['/verification', '/workflows'];

/// Route table mirrors the `lib/features/` layout one-to-one
/// (`doc/MOBILE-SPECIFICATION.md` §3.1/§3.3) — no route lives outside its
/// feature's folder. Each feature wires its own routes in here as it lands.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/sign-in',
    redirect: (context, state) {
      final isOfficerOnly = _officerOnlyPrefixes.any(
        (prefix) => state.matchedLocation.startsWith(prefix),
      );
      if (!isOfficerOnly) return null;

      final auth = ref.read(authControllerProvider);
      final role = auth is AuthAuthenticated ? auth.role : null;
      return role == 'InventoryOfficer' ? null : '/home';
    },
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
      // features/verification/ — FR-058 task list, FR-059 completion,
      // FR-061 manual discrepancy raising. Officer only — see redirect above.
      GoRoute(
        path: '/verification',
        builder: (context, state) => const VerificationTaskListScreen(),
      ),
      GoRoute(
        path: '/verification/:taskId',
        builder: (context, state) => VerificationTaskDetailScreen(
          taskId: state.pathParameters['taskId']!,
        ),
      ),
      GoRoute(
        path: '/verification/:taskId/discrepancy',
        builder: (context, state) => RaiseDiscrepancyScreen(
          taskId: state.pathParameters['taskId']!,
        ),
      ),
      // features/workflows/ — FR-067/FR-068 initiate, FR-069/FR-076
      // status/outcome. Officer only — see redirect above.
      GoRoute(
        path: '/workflows',
        builder: (context, state) => const WorkflowListScreen(),
      ),
      GoRoute(
        path: '/workflows/new',
        builder: (context, state) => const InitiateWorkflowScreen(),
      ),
      GoRoute(
        path: '/workflows/:id',
        builder: (context, state) =>
            WorkflowDetailScreen(workflowId: state.pathParameters['id']!),
      ),
    ],
  );
});
