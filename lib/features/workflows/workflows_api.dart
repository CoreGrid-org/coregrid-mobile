import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/api_client.dart';
import '../../shared/api/api_exception.dart';
import 'models/agent_workflow.dart';
import 'models/workflow_asset_ref.dart';

/// Every `/api/agent-workflows` call this feature owns
/// (`MOBILE-SPECIFICATION.md` §3.1/§4.9). Note: §4.9 as written names
/// `/api/workflows` — the real backend route is `/api/agent-workflows`
/// (`AgentWorkflowsController`); this client follows the backend, and
/// §4.9 should be corrected to match.
class WorkflowsApi {
  WorkflowsApi(this._dio);

  final Dio _dio;

  /// `GET /api/agent-workflows` (FR-069) — every workflow the caller may see;
  /// filtering to "mine" happens client-side since the backend doesn't
  /// accept an `initiatedBy` filter.
  Future<List<AgentWorkflow>> getWorkflows() async {
    try {
      final response = await _dio.get<List<dynamic>>('/api/agent-workflows');
      return (response.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AgentWorkflow.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /api/agent-workflows/{id}` (FR-069/FR-076) — polled by the status
  /// screen until the workflow resolves.
  Future<AgentWorkflow> getWorkflowById(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/agent-workflows/$id',
      );
      final data = response.data;
      if (data == null) {
        throw ApiException(
          statusCode: response.statusCode ?? 0,
          message: 'CoreGrid returned an empty response.',
        );
      }
      return AgentWorkflow.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /api/agent-workflows` (FR-067/FR-068) — returns a workflow id
  /// immediately; the backend runs the evaluation asynchronously (the
  /// Planner/Policy-Compliance agents are backend-internal — this app never
  /// calls `/evaluate` or `/run-policy-agent` directly).
  Future<AgentWorkflow> createWorkflow({
    required String assetId,
    required String objective,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/agent-workflows',
        data: {'asset_id': assetId, 'objective': objective.trim()},
      );
      final data = response.data;
      if (data == null) {
        throw ApiException(
          statusCode: response.statusCode ?? 0,
          message: 'CoreGrid returned an empty response.',
        );
      }
      return AgentWorkflow.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /api/assets/qr/{code}` — resolves the asset to initiate a
  /// workflow for, by manually-typed code (no scan yet, same stand-in
  /// `features/assets/`/`features/verification/` already use).
  Future<WorkflowAssetRef> resolveAssetByCode(String code) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/assets/qr/${Uri.encodeComponent(code.trim())}',
      );
      final data = response.data;
      if (data == null) {
        throw ApiException(
          statusCode: response.statusCode ?? 0,
          message: 'CoreGrid returned an empty response.',
        );
      }
      return WorkflowAssetRef.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final workflowsApiProvider = Provider<WorkflowsApi>((ref) {
  return WorkflowsApi(ref.watch(apiClientProvider));
});
