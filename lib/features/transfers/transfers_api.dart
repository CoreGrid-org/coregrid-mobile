import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/api_client.dart';
import '../../shared/api/api_exception.dart';
import 'models/condemn_asset_request.dart';
import 'models/condemn_asset_response.dart';
import 'models/initiate_transfer_request.dart';
import 'models/transfer_response.dart';

/// Every `/api/transfers` and `/api/assets/{id}/condemn` call owned by
/// `features/transfers/`, over the shared Dio client. All failures are
/// normalised to [ApiException] so providers and screens never see a raw
/// [DioException].
class TransfersApi {
  TransfersApi(this._dio);

  final Dio _dio;

  /// `POST /api/transfers` — FR-043. Requires CanRequestTransfer policy
  /// (InventoryOfficer, Administrator). Returns 201 Created with the new
  /// [TransferResponse] body.
  Future<TransferResponse> initiateTransfer(
    InitiateTransferRequest request,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/transfers',
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw ApiException(
          statusCode: response.statusCode ?? 0,
          message: 'CoreGrid returned an empty response.',
        );
      }
      return TransferResponse.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /api/transfers` — org-scoped list, newest first (backend default).
  /// Optional [status] filter maps to the status query parameter.
  Future<List<TransferResponse>> getTransfers({String? status}) async {
    try {
      final queryParams = <String, dynamic>{'page_size': 50};
      if (status != null) {
        queryParams['status'] = status;
      }
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/transfers',
        queryParameters: queryParams,
      );
      final items = response.data?['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(TransferResponse.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /api/transfers/{id}` — single transfer detail.
  Future<TransferResponse> getById(String transferId) {
    return _get('/api/transfers/$transferId', TransferResponse.fromJson);
  }

  /// `POST /api/transfers/{id}/confirm-receipt` — FR-046. No request body.
  /// Requires CanConfirmReceipt policy (InventoryOfficer, Administrator).
  Future<TransferResponse> confirmReceipt(String transferId) {
    return _post('/api/transfers/$transferId/confirm-receipt');
  }

  /// `POST /api/assets/{id}/condemn` — FR-049. Requires CanRequestDisposal
  /// policy (InventoryOfficer, Administrator). Returns 200 OK with the new
  /// [CondemnAssetResponse] body.
  Future<CondemnAssetResponse> condemnAsset({
    required String assetId,
    required CondemnAssetRequest request,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/assets/$assetId/condemn',
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw ApiException(
          statusCode: response.statusCode ?? 0,
          message: 'CoreGrid returned an empty response.',
        );
      }
      return CondemnAssetResponse.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /api/verification-tasks/photos` — uploads photo evidence for
  /// condemnation (reusing the backend storage endpoint authorized for
  /// InventoryOfficer). Returns private storage key / URL for [evidenceUrl].
  Future<String> uploadEvidencePhoto({
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/verification-tasks/photos',
        data: FormData.fromMap({
          'photo': MultipartFile.fromBytes(bytes, filename: fileName),
        }),
      );
      final url = response.data?['url'] as String?;
      if (url == null || url.isEmpty) {
        throw ApiException(
          statusCode: response.statusCode ?? 0,
          message: 'CoreGrid did not return a photo URL.',
        );
      }
      return url;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  Future<TransferResponse> _get(
    String path,
    TransferResponse Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path);
      final data = response.data;
      if (data == null) {
        throw ApiException(
          statusCode: response.statusCode ?? 0,
          message: 'CoreGrid returned an empty response.',
        );
      }
      return parse(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<TransferResponse> _post(String path) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path);
      final data = response.data;
      if (data == null) {
        throw ApiException(
          statusCode: response.statusCode ?? 0,
          message: 'CoreGrid returned an empty response.',
        );
      }
      return TransferResponse.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final transfersApiProvider = Provider<TransfersApi>((ref) {
  return TransfersApi(ref.watch(apiClientProvider));
});
