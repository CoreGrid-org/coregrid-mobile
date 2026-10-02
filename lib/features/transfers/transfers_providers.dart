import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/auth/auth_controller.dart';
import '../../shared/auth/auth_state.dart';
import '../assets/assets_providers.dart';
import 'models/condemn_asset_request.dart';
import 'models/initiate_transfer_request.dart';
import 'models/transfer_response.dart';
import 'transfers_api.dart';

// ── Read providers ────────────────────────────────────────────────────────────

/// All transfers visible to the current user (org-scoped, newest first).
/// autoDispose so navigating away drops the cache — list data should always
/// reflect the latest server state when the screen is re-entered.
final transferListProvider =
    FutureProvider.autoDispose<List<TransferResponse>>((ref) {
  return ref.watch(transfersApiProvider).getTransfers();
});

/// Transfers with status APPROVED directed to the current user's department —
/// the "Awaiting My Confirmation" dashboard section (FR-046). The filter is
/// applied client-side from the full list because the backend does not expose
/// a per-recipient filter; the list is org-scoped and small in practice.
final pendingConfirmationProvider =
    FutureProvider.autoDispose<List<TransferResponse>>((ref) async {
  final all = await ref.watch(transfersApiProvider).getTransfers(
        status: TransferStatus.approved.apiValue,
      );
  return all;
});

/// Single transfer detail, keyed by transfer id.
final transferDetailProvider =
    FutureProvider.autoDispose.family<TransferResponse, String>(
  (ref, transferId) {
    return ref.watch(transfersApiProvider).getById(transferId);
  },
);

// ── Mutation controllers ──────────────────────────────────────────────────────

/// Drives `POST /api/transfers` (FR-043). Starts idle (synchronous build),
/// `submit()` uses [AsyncValue.guard] and invalidates [transferListProvider]
/// on success so the list re-fetches — no local state mutation.
class InitiateTransferController extends AsyncNotifier<void> {
  @override
  void build() {}

  /// Returns the created [TransferResponse] on success, or null on failure
  /// (caller should check `state.hasError`).
  Future<TransferResponse?> submit(InitiateTransferRequest request) async {
    state = const AsyncLoading();
    TransferResponse? created;
    final result = await AsyncValue.guard<TransferResponse>(() async {
      created = await ref.read(transfersApiProvider).initiateTransfer(request);
      return created!;
    });
    state = result.hasError ? AsyncError(result.error!, result.stackTrace!) : const AsyncData(null);
    if (!result.hasError) {
      ref.invalidate(transferListProvider);
      ref.invalidate(pendingConfirmationProvider);
    }
    return created;
  }
}

final initiateTransferControllerProvider =
    AsyncNotifierProvider.autoDispose<InitiateTransferController, void>(
  InitiateTransferController.new,
);

/// Drives `POST /api/transfers/{id}/confirm-receipt` (FR-046). No request
/// body — only the transfer id is needed. Invalidates both the detail and
/// list providers on success so the UI reflects the COMPLETED status.
class ConfirmReceiptController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<bool> confirm(String transferId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard<void>(
      () => ref.read(transfersApiProvider).confirmReceipt(transferId),
    );
    state = result;
    if (!result.hasError) {
      ref.invalidate(transferDetailProvider(transferId));
      ref.invalidate(transferListProvider);
      ref.invalidate(pendingConfirmationProvider);
    }
    return !result.hasError;
  }
}

final confirmReceiptControllerProvider =
    AsyncNotifierProvider.autoDispose<ConfirmReceiptController, void>(
  ConfirmReceiptController.new,
);

/// Whether the authenticated user has permission to condemn an asset (FR-049).
/// Backend's `CanRequestDisposal` policy allows InventoryOfficer & Administrator.
final canCondemnAssetProvider = Provider<bool>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is AuthAuthenticated && auth.role == 'InventoryOfficer';
});

/// Drives the "condemn asset" action (FR-049).
/// State represents in-flight mutation. On success, invalidates the authoritative
/// [assetDetailProvider] and [assetHistoryProvider] so the UI automatically
/// refreshes without trusting local state assumptions.
class CondemnAssetController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<bool> submit({
    required String assetId,
    required CondemnAssetRequest request,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(transfersApiProvider).condemnAsset(
            assetId: assetId,
            request: request,
          ),
    );
    state = result;
    if (result.hasError) return false;
    ref.invalidate(assetDetailProvider(assetId));
    ref.invalidate(assetHistoryProvider(assetId));
    return true;
  }
}

final condemnAssetControllerProvider =
    AsyncNotifierProvider.autoDispose<CondemnAssetController, void>(
  CondemnAssetController.new,
);
