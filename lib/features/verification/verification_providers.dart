import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/discrepancy.dart';
import 'models/verification_location.dart';
import 'models/verification_task.dart';
import 'verification_api.dart';

/// The signed-in officer's outstanding verification tasks (FR-058),
/// `autoDispose` so returning to the list after completing/raising a
/// discrepancy against a task always re-reads the authoritative state
/// rather than a stale cache.
final myVerificationTasksProvider =
    FutureProvider.autoDispose<List<VerificationTask>>((ref) {
      return ref.watch(verificationApiProvider).getTasks(mine: true);
    });

/// One task, resolved from the list above by id — the task detail/complete
/// screen reads this rather than re-fetching, since `GET
/// /api/verification-tasks` has no single-resource endpoint.
final verificationTaskProvider = Provider.autoDispose
    .family<AsyncValue<VerificationTask?>, String>((ref, taskId) {
      final tasks = ref.watch(myVerificationTasksProvider);
      return tasks.whenData(
        (list) => list.where((t) => t.id == taskId).firstOrNull,
      );
    });

/// Locations for the "asserted location" picker — org-wide, changes rarely,
/// so this is `keepAlive` rather than `autoDispose`.
final verificationLocationsProvider =
    FutureProvider<List<VerificationLocation>>((ref) {
      return ref.watch(verificationApiProvider).getLocations();
    });

/// Drives "complete task" (FR-059). Holds only the in-flight mutation state
/// — the task list is invalidated on success so the list screen re-reads the
/// authoritative record (which now carries the auto-raised-discrepancy
/// side effect from FR-060, if any).
class CompleteVerificationTaskController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<VerificationTask?> submit({
    required String taskId,
    required bool assertedPresent,
    String? assertedLocationId,
    String? assertedCondition,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(verificationApiProvider)
          .completeTask(
            taskId: taskId,
            assertedPresent: assertedPresent,
            assertedLocationId: assertedLocationId,
            assertedCondition: assertedCondition,
          ),
    );
    state = result.hasError ? AsyncError(result.error!, result.stackTrace!) : const AsyncData(null);
    if (result.hasError) return null;
    ref.invalidate(myVerificationTasksProvider);
    return result.value;
  }
}

final completeVerificationTaskControllerProvider =
    AsyncNotifierProvider.autoDispose<CompleteVerificationTaskController, void>(
      CompleteVerificationTaskController.new,
    );

/// Drives "raise discrepancy manually" (FR-061), including the optional
/// photo upload (IF-11 — compression happens before this controller is
/// invoked, in the screen).
class RaiseDiscrepancyController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<bool> submit({
    required String taskId,
    required DiscrepancyType type,
    required String description,
    List<int>? photoBytes,
    String? photoFileName,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final api = ref.read(verificationApiProvider);
      String? photoUrl;
      if (photoBytes != null) {
        photoUrl = await api.uploadPhoto(
          bytes: photoBytes,
          fileName: photoFileName ?? 'discrepancy.jpg',
        );
      }
      return api.raiseDiscrepancy(
        taskId: taskId,
        type: type,
        description: description,
        photoUrl: photoUrl,
      );
    });
    state = result.hasError ? AsyncError(result.error!, result.stackTrace!) : const AsyncData(null);
    return !result.hasError;
  }
}

final raiseDiscrepancyControllerProvider =
    AsyncNotifierProvider.autoDispose<RaiseDiscrepancyController, void>(
      RaiseDiscrepancyController.new,
    );
