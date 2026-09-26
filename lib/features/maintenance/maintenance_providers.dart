import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/assets/assets_api.dart';
import '../../features/assets/models/asset/asset_detail.dart';
import '../../features/assets/models/asset/asset_search.dart';
import 'maintenance_api.dart';
import 'models/fault_report.dart';

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
    }
    return !result.hasError;
  }
}

final reportFaultControllerProvider =
    AsyncNotifierProvider.autoDispose<ReportFaultController, void>(
      ReportFaultController.new,
    );
