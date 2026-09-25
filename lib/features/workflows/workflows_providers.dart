import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/agent_workflow.dart';
import 'models/workflow_asset_ref.dart';
import 'workflows_api.dart';

/// Agent workflows visible to the signed-in officer, newest first.
final agentWorkflowsProvider = FutureProvider.autoDispose<List<AgentWorkflow>>((
  ref,
) async {
  final workflows = await ref.watch(workflowsApiProvider).getWorkflows();
  return workflows.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

/// One workflow's status/outcome, polled every 5s while unresolved.
final agentWorkflowProvider = StreamProvider.autoDispose
    .family<AgentWorkflow, String>((ref, id) async* {
      final api = ref.watch(workflowsApiProvider);
      while (true) {
        final workflow = await api.getWorkflowById(id);
        yield workflow;
        if (workflow.isResolved || workflow.isFailed) return;
        await Future<void>.delayed(const Duration(seconds: 5));
      }
    });

/// Resolves a manually-typed asset code before initiating a workflow.
class WorkflowAssetLookupController extends AsyncNotifier<WorkflowAssetRef?> {
  @override
  WorkflowAssetRef? build() => null;

  Future<void> lookup(String code) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(workflowsApiProvider).resolveAssetByCode(code),
    );
  }

  void reset() => state = const AsyncData(null);
}

final workflowAssetLookupControllerProvider =
    AsyncNotifierProvider.autoDispose<WorkflowAssetLookupController, WorkflowAssetRef?>(
      WorkflowAssetLookupController.new,
    );

/// Drives "Request Evaluation".
class InitiateWorkflowController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<AgentWorkflow?> submit({
    required String assetId,
    required String objective,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(workflowsApiProvider)
          .createWorkflow(assetId: assetId, objective: objective),
    );
    state = result.hasError
        ? AsyncError(result.error!, result.stackTrace!)
        : const AsyncData(null);
    if (result.hasError) return null;
    ref.invalidate(agentWorkflowsProvider);
    return result.value;
  }
}

final initiateWorkflowControllerProvider =
    AsyncNotifierProvider.autoDispose<InitiateWorkflowController, void>(
      InitiateWorkflowController.new,
    );
