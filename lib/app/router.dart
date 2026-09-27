import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/assets/screens/asset/asset_detail_screen.dart';
import '../features/assets/screens/asset/asset_lookup_screen.dart';
import '../features/assets/screens/asset/asset_search_screen.dart';
import '../features/assets/screens/asset/asset_verification_screen.dart';
import '../features/assets/models/asset/asset_detail.dart';
import '../features/scan/screens/scan_asset_screen.dart';
import '../features/auth/screens/access_restricted_screen.dart';
import '../features/auth/screens/sign_in_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/maintenance/screens/report_fault_screen.dart';
import '../features/maintenance/screens/fault_detail_screen.dart';
import '../features/maintenance/models/fault_report.dart';
import '../features/verification/screens/raise_discrepancy_screen.dart';
import '../features/verification/screens/verification_task_detail_screen.dart';
import '../features/verification/screens/verification_task_list_screen.dart';
import '../features/workflows/screens/initiate_workflow_screen.dart';
import '../features/workflows/screens/workflow_detail_screen.dart';
import '../features/workflows/screens/workflow_list_screen.dart';
import '../features/transfers/screens/confirm_receipt_scan_screen.dart';
import '../features/transfers/screens/initiate_transfer_screen.dart';
import '../features/transfers/screens/transfer_detail_screen.dart';
import '../features/transfers/screens/transfer_list_screen.dart';
import '../features/account/screens/account_screen.dart';
import '../features/maintenance/screens/my_faults_screen.dart';
import '../features/verification/screens/campaign_detail_screen.dart';
import '../shared/auth/auth_controller.dart';
import '../shared/auth/auth_state.dart';
import 'app_shell.dart';

/// `features/verification/` and `features/workflows/` are Inventory Officer
/// only on mobile. The shell never shows these tabs to a Staff session, but
/// a direct navigation is still guarded here.
const _officerOnlyPrefixes = ['/verification', '/workflows', '/campaigns'];

bool _isOfficerOnly(String location) =>
    _officerOnlyPrefixes.any(location.startsWith) ||
    // Ad-hoc verification (FR-031) — `/assets/:id/verify`.
    (location.startsWith('/assets/') && location.endsWith('/verify'));

/// Route table mirrors the `lib/features/` layout one-to-one
/// (`doc/MOBILE-SPECIFICATION.md` Â§3.1/Â§3.3) â€” no route lives outside its
/// feature's folder. Each feature wires its own routes in here as it lands.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    redirect: (context, state) {
      if (!_isOfficerOnly(state.matchedLocation)) return null;

      final auth = ref.read(authControllerProvider);
      final role = auth is AuthAuthenticated ? auth.role : null;
      return role == 'InventoryOfficer' ? null : '/home';
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      // Signed-in tabs. Branch order must match `ShellBranch`.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/verification',
                builder: (context, state) => VerificationTaskListScreen(
                  showCampaigns:
                      state.uri.queryParameters['view'] == 'campaigns',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/workflows',
                builder: (context, state) => const WorkflowListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/faults',
                builder: (context, state) => const MyFaultsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/access-restricted',
        builder: (context, state) =>
            AccessRestrictedScreen(role: state.extra as String? ?? ''),
      ),
      // Manual asset-code entry fallback.
      GoRoute(
        path: '/assets',
        builder: (context, state) => const AssetLookupScreen(),
      ),
      GoRoute(
        path: '/assets/search',
        builder: (context, state) => AssetSearchScreen(
          initialQuery: state.uri.queryParameters['q'] ?? '',
        ),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => ScanAssetScreen(
          identify: state.uri.queryParameters['purpose'] == 'identify',
        ),
      ),
      // Ad-hoc verification (FR-031). Officer only.
      GoRoute(
        path: '/assets/:id/verify',
        builder: (context, state) => AssetVerificationScreen(
          assetId: state.pathParameters['id']!,
          initialAsset: state.extra as AssetDetail?,
        ),
      ),
      // Asset detail â€” reached from manual lookup or scan.
      GoRoute(
        path: '/assets/:id',
        builder: (context, state) => AssetDetailScreen(
          assetId: state.pathParameters['id']!,
          initialAsset: state.extra as AssetDetail?,
        ),
      ),
      // Fault reporting, available to Staff and Officer.
      GoRoute(
        path: '/maintenance/report',
        builder: (context, state) {
          final extra = state.extra as Map<String, String?>?;
          return ReportFaultScreen(
            assetId: extra?['assetId'],
            assetCode: extra?['assetCode'],
          );
        },
      ),
      // features/maintenance/ â€” details for a fault report selected from the
      // signed-in user's dashboard list.
      GoRoute(
        path: '/maintenance/:id',
        builder: (context, state) =>
            FaultDetailScreen(report: state.extra as FaultReport),
      ),
      // Verification task detail / discrepancy and read-only campaign detail
      // push full-screen over the tabs. Officer only.
      GoRoute(
        path: '/campaigns/:id',
        builder: (context, state) =>
            CampaignDetailScreen(campaignId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/verification/:taskId',
        builder: (context, state) => VerificationTaskDetailScreen(
          taskId: state.pathParameters['taskId']!,
          scanned: state.uri.queryParameters['scanned'] == '1',
        ),
      ),
      GoRoute(
        path: '/verification/:taskId/discrepancy',
        builder: (context, state) =>
            RaiseDiscrepancyScreen(taskId: state.pathParameters['taskId']!),
      ),
      // Transfer routes (FR-043/FR-046). Officer only — see _officerOnlyPrefixes.
      GoRoute(
        path: '/transfers',
        builder: (context, state) => const TransferListScreen(),
      ),
      GoRoute(
        path: '/transfers/new',
        builder: (context, state) => const InitiateTransferScreen(),
      ),
      GoRoute(
        path: '/transfers/:id',
        builder: (context, state) =>
            TransferDetailScreen(transferId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/transfers/:id/confirm-scan',
        builder: (context, state) =>
            ConfirmReceiptScanScreen(transferId: state.pathParameters['id']!),
      ),
            // Workflows routes. Officer only.
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

