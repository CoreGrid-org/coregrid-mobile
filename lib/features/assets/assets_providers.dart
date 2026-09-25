import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/api_client.dart';
import '../../shared/auth/auth_controller.dart';
import '../../shared/auth/auth_state.dart';
import 'assets_api.dart';
import 'models/asset/asset_condition.dart';
import 'models/asset/asset_detail.dart';
import 'models/asset/asset_history_entry.dart';
import 'models/asset/asset_maintenance_history.dart';
import 'models/asset/asset_search.dart';

/// The asset shown on the detail screen, keyed by asset id (§3.2 — one
/// provider per feature-level concern, screens just `watch` it). `autoDispose`
/// so leaving the screen drops the cached record — a field user re-scanning
/// should always get a fresh read, never a stale one (FR-024 A4).
final assetDetailProvider = FutureProvider.autoDispose
    .family<AssetDetail, String>((ref, assetId) {
      return ref.watch(assetsApiProvider).getById(assetId);
    });

/// Search always uses the backend API. The mock-data switch is intentionally
/// not applied here because FR-025 search validation must exercise the real
/// server-side filters, sorting, and pagination contract.
final realAssetsSearchApiProvider = Provider<SearchableAssetsApi>((ref) {
  return SearchableAssetsApiClient(ref.watch(apiClientProvider));
});

final realAssetsCatalogApiProvider = Provider<AssetsApi>((ref) {
  return SearchableAssetsApiClient(ref.watch(apiClientProvider));
});

final assetFilterOptionsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, resourcePath) {
      return ref
          .watch(realAssetsCatalogApiProvider)
          .getFilterOptions(resourcePath);
    });

final assetSearchProvider = FutureProvider.autoDispose
    .family<AssetSearchResult, AssetSearchQuery>((ref, query) {
      return ref.watch(realAssetsSearchApiProvider).search(query);
    });

/// The asset's lifecycle history, loaded lazily when the user expands the
/// History section (FR-027).
final assetHistoryProvider = FutureProvider.autoDispose
    .family<List<AssetHistoryEntry>, String>((ref, assetId) {
      return ref.watch(assetsApiProvider).getHistory(assetId);
    });

final assetMaintenanceHistoryProvider = FutureProvider.autoDispose
    .family<AssetMaintenanceHistory, String>((ref, assetId) {
      return ref.watch(assetsApiProvider).getMaintenanceHistory(assetId);
    });

/// Whether the current user may perform a physical verification (FR-031 /
/// FR-024 AC4). Officer only — Staff never see the Verify action, and a direct
/// API call by Staff is rejected 403 server-side regardless.
final canVerifyAssetsProvider = Provider<bool>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is AuthAuthenticated && auth.role == 'InventoryOfficer';
});

/// Whether the current user may record an asset condition (FR-029). The
/// backend's `CanManageAssets` policy rejects Staff with 403, so hide the
/// action for that role rather than offering an operation that cannot succeed.
final canUpdateAssetConditionProvider = Provider<bool>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is AuthAuthenticated && auth.role == 'InventoryOfficer';
});

/// Drives the "record condition" action (FR-029). Holds only the in-flight
/// state of the mutation — the asset itself lives in [assetDetailProvider],
/// which this invalidates on success so the screen re-reads the authoritative
/// value rather than trusting a local guess.
class ConditionUpdateController extends AsyncNotifier<void> {
  // Synchronous build — the controller starts idle (AsyncData), not loading;
  // `state.isLoading` means "an update is in flight".
  @override
  void build() {}

  Future<bool> submit({
    required String assetId,
    required AssetCondition condition,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(assetsApiProvider)
          .updateCondition(assetId: assetId, condition: condition),
    );
    state = result;
    if (result.hasError) return false;
    ref.invalidate(assetDetailProvider(assetId));
    ref.invalidate(assetHistoryProvider(assetId));
    return true;
  }
}

final conditionUpdateControllerProvider =
    AsyncNotifierProvider.autoDispose<ConditionUpdateController, void>(
      ConditionUpdateController.new,
    );

/// Resolves a manually-typed asset code to its record (FR-025). Holds only the
/// in-flight lookup — the resolved asset is handed to the detail screen via
/// navigation, which re-reads it by id (AC3: same record either way).
class AssetLookupController extends AsyncNotifier<AssetDetail?> {
  // Synchronous build — starts idle with no result, not in a loading state.
  @override
  AssetDetail? build() => null;

  Future<void> lookup(String code) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(assetsApiProvider).getByCode(code),
    );
  }

  /// Clears the result after navigation so returning to the lookup screen
  /// starts from a blank field, not the last hit.
  void reset() => state = const AsyncData(null);
}

final assetLookupControllerProvider =
    AsyncNotifierProvider.autoDispose<AssetLookupController, AssetDetail?>(
      AssetLookupController.new,
    );
