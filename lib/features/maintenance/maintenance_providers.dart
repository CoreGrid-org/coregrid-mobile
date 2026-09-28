import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/assets/assets_api.dart';
import '../../features/assets/models/asset/asset_detail.dart';
import '../../features/assets/models/asset/asset_search.dart';
import '../../shared/auth/auth_controller.dart';
import '../../shared/auth/auth_state.dart';
import '../../shared/auth/me_provider.dart';
import 'maintenance_api.dart';
import 'models/fault_report.dart';
import 'models/maintenance_filter.dart';

/// The signed-in user's own fault reports.
/// The API derives the owner from the bearer token; no client-side identity
/// filter or unscoped fallback is allowed.
final myFaultReportsProvider = FutureProvider.autoDispose<List<FaultReport>>((
  ref,
) async {
  return ref.watch(maintenanceApiProvider).getMyReports();
});

/// Searches assets the current user can access, filtered by the search term
/// they type in the asset picker. Results are scoped by the backend to the
/// user's department automatically.
final faultAssetSearchProvider = FutureProvider.autoDispose
    .family<List<AssetDetail>, String>((ref, search) async {
      final result = await ref
          .watch(assetsApiProvider)
          .search(AssetSearchQuery(search: search, pageSize: 30));
      return result.items;
    });

/// Drives "report fault", including optional photo upload.
class ReportFaultController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<bool> submit({
    required String assetId,
    required String description,
    required String observedCondition,
    String? assetCode,
    List<int>? photoBytes,
    String? photoFileName,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final api = ref.read(maintenanceApiProvider);
      String? photoUrl;
      if (photoBytes != null && photoBytes.isNotEmpty) {
        photoUrl = await api.uploadPhoto(
          bytes: photoBytes,
          fileName: photoFileName ?? 'fault.jpg',
        );
      }
      await api.reportFault(
        assetId: assetId,
        description: description,
        observedCondition: observedCondition,
        photoUrl: photoUrl,
      );
    });

    state = result.hasError
        ? AsyncError(result.error!, result.stackTrace!)
        : const AsyncData(null);

    if (!result.hasError) {
      ref.invalidate(myFaultReportsProvider);
      ref.invalidate(maintenancePageProvider);
    }
    return !result.hasError;
  }
}

final reportFaultControllerProvider =
    AsyncNotifierProvider.autoDispose<ReportFaultController, void>(
      ReportFaultController.new,
    );

// ── FR-042 / FR-037 — maintenance records (Officer) ───────────────────────────

/// Whether the signed-in user may work maintenance records on mobile: list
/// all of them (FR-042) and start assigned work (FR-037). Officer only — the
/// API's `CanManageMaintenance` also admits Administrators, who don't use
/// this app.
final canManageMaintenanceProvider = Provider<bool>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is AuthAuthenticated && auth.role == 'InventoryOfficer';
});

/// One page of `GET /api/maintenance` for a filter — the list screen
/// watches pages 1..n and concatenates them ("Load more").
final maintenancePageProvider = FutureProvider.autoDispose
    .family<MaintenancePage, (MaintenanceFilter, int)>((ref, key) {
      final (filter, page) = key;
      return ref.watch(maintenanceApiProvider).listRecords(filter, page: page);
    });

/// Open work assigned to the signed-in officer (APPROVED or IN_PROGRESS) —
/// the dashboard's "Maintenance assigned to me".
final myAssignedMaintenanceProvider =
    FutureProvider.autoDispose<List<FaultReport>>((ref) async {
      final me = await ref.watch(meProvider.future);
      if (me.id.isEmpty) return const [];
      final api = ref.watch(maintenanceApiProvider);
      final pages = await Future.wait([
        for (final status in [
          MaintenanceStatus.inProgress,
          MaintenanceStatus.approved,
        ])
          api.listRecords(MaintenanceFilter(assigneeId: me.id, status: status)),
      ]);
      return [for (final p in pages) ...p.items];
    });

/// One maintenance record by id (`GET /api/maintenance/{id}`).
final maintenanceRecordProvider = FutureProvider.autoDispose
    .family<FaultReport, String>((ref, id) {
      return ref.watch(maintenanceApiProvider).getRecord(id);
    });

/// Drives FR-037's mobile transition — start work on an APPROVED record.
class StartMaintenanceController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<bool> start(String id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(maintenanceApiProvider).startWork(id),
    );
    if (!ref.mounted) return !result.hasError;
    state = result.hasError
        ? AsyncError(result.error!, result.stackTrace!)
        : const AsyncData(null);
    if (!result.hasError) {
      ref.invalidate(maintenanceRecordProvider(id));
      ref.invalidate(maintenancePageProvider);
      ref.invalidate(myAssignedMaintenanceProvider);
      ref.invalidate(myFaultReportsProvider);
    }
    return !result.hasError;
  }
}

final startMaintenanceControllerProvider =
    AsyncNotifierProvider.autoDispose<StartMaintenanceController, void>(
      StartMaintenanceController.new,
    );
