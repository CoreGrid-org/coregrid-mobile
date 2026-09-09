import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/api_client.dart';
import '../../shared/api/api_exception.dart';
import '../../shared/auth/auth_config.dart';
import 'models/asset/asset_condition.dart';
import 'models/asset/asset_detail.dart';
import 'models/asset/asset_history_entry.dart';
import 'models/asset/asset_search.dart';
import 'models/asset/asset_verification.dart';
import 'mock_assets_api.dart';

abstract interface class SearchableAssetsApi {
  Future<AssetSearchResult> search(AssetSearchQuery query);
}

abstract interface class VerifiableAssetsApi {
  Future<AssetVerificationResult> verifyAsset({
    required String assetId,
    required AssetVerificationRequest request,
  });
}

/// Every `/api/assets` call `features/assets/` owns, over the shared dio
/// client (`MOBILE-SPECIFICATION.md` §3.1 — API calls live with the feature).
/// All failures are normalised to [ApiException] so providers/screens never
/// see a raw [DioException].
class AssetsApi {
  AssetsApi(this._dio);

  final Dio _dio;

  /// `GET /api/assets/{id}` — the authoritative record for the detail screen
  /// (FR-020, §4.4). A cross-organisation id returns 404, never 403 (AC2).
  Future<AssetDetail> getById(String assetId) {
    return _get('/api/assets/$assetId', AssetDetail.fromJson);
  }

  /// `GET /api/assets/qr/{code}` — manual-entry / scan resolution (FR-024,
  /// FR-025). Byte-identical to [getById]'s body for the same asset (AC3).
  Future<AssetDetail> getByCode(String assetCode) {
    return _get(
      '/api/assets/qr/${Uri.encodeComponent(assetCode.trim())}',
      AssetDetail.fromJson,
    );
  }

  /// `PATCH /api/assets/{id}/condition` — records a new condition on the
  /// defined scale (FR-029). Returns 204; the change is written to asset
  /// history server-side.
  Future<void> updateCondition({
    required String assetId,
    required AssetCondition condition,
  }) async {
    try {
      await _dio.patch<void>(
        '/api/assets/$assetId/condition',
        data: {'condition': condition.apiValue},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }


  /// `GET /api/assets/{id}/history` — the immutable lifecycle log (FR-027),
  /// newest first as the backend orders it. `page`/`page_size` map to the
  /// backend's `AssetHistoryQueryParameters`.
  Future<List<AssetHistoryEntry>> getHistory(
    String assetId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/assets/$assetId/history',
        queryParameters: {'page': page, 'page_size': pageSize},
      );
      final items = response.data?['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(AssetHistoryEntry.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<T> _get<T>(
    String path,
    T Function(Map<String, dynamic>) parse,
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
}

class SearchableAssetsApiClient extends AssetsApi
  implements SearchableAssetsApi, VerifiableAssetsApi {
  SearchableAssetsApiClient(super.dio);

  @override
  Future<AssetSearchResult> search(AssetSearchQuery query) async {
    try {
      final response = await _dio.get<Object>(
        '/api/assets',
        queryParameters: query.toQueryParameters(),
      );
      final data = response.data;
      if (data is List) {
        return AssetSearchResult(
          items: data
              .whereType<Map<String, dynamic>>()
              .map(AssetDetail.fromJson)
              .toList(),
          page: query.page,
          pageSize: query.pageSize,
          totalCount: data.length,
        );
      }
      if (data is Map<String, dynamic>) {
        return AssetSearchResult.fromJson(data);
      }
      throw ApiException(
        statusCode: response.statusCode ?? 0,
        message: 'CoreGrid returned an empty response.',
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<AssetVerificationResult> verifyAsset({
    required String assetId,
    required AssetVerificationRequest request,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/assets/$assetId/verify',
        data: request.toJson(),
      );
      return AssetVerificationResult.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final assetsApiProvider = Provider<AssetsApi>((ref) {
  if (AuthConfig.useMockData) return MockAssetsApi();
  return SearchableAssetsApiClient(ref.watch(apiClientProvider));
});
