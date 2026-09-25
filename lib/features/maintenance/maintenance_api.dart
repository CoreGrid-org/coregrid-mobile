import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/api_client.dart';
import '../../shared/api/api_exception.dart';
import 'models/fault_report.dart';

/// Every `/api/maintenance` call this feature owns
/// (`MOBILE-SPECIFICATION.md` §3.1). All failures are normalised to
/// [ApiException] so providers/screens never see a raw [DioException] (§3.4).
class MaintenanceApi {
  MaintenanceApi(this._dio);

  final Dio _dio;

  /// `GET /api/maintenance/my-reports` — reports raised by the authenticated
  /// user. Ownership is enforced by the backend from the bearer token.
  ///
  /// Never fall back to an unscoped maintenance endpoint here: a fallback
  /// could disclose another user's fault reports on a mobile dashboard.
  Future<List<FaultReport>> getMyReports() async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/maintenance/my-reports',
        queryParameters: const {'page': 1, 'pageSize': 20},
      );

      final data = response.data;
      List<dynamic> rawList = const [];
      if (data is List) {
        rawList = data;
      } else if (data is Map<String, dynamic>) {
        final listCandidate =
            data['items'] ??
            data['data'] ??
            data['faults'] ??
            data['records'] ??
            data['results'] ??
            data['value'];
        if (listCandidate is List) {
          rawList = listCandidate;
        }
      }

      return rawList
          .whereType<Map<String, dynamic>>()
          .map(FaultReport.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /api/maintenance/photos` — uploads the fault photo (already
  /// compressed client-side to ≤1MB, IF-11) and returns the stored URL to
  /// pass as `photo_url` to [reportFault].
  Future<String> uploadPhoto({
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'photo': MultipartFile.fromBytes(bytes, filename: fileName),
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      });

      final response = await _dio.post<dynamic>(
        '/api/maintenance/photos',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      final data = response.data;
      if (data is String && data.isNotEmpty) {
        return data;
      }
      if (data is Map<String, dynamic>) {
        final url =
            (data['url'] ??
                    data['photo_url'] ??
                    data['photoUrl'] ??
                    data['file_url'] ??
                    data['fileUrl'] ??
                    data['path'] ??
                    data['filePath'])
                as String?;
        if (url != null && url.isNotEmpty) {
          return url;
        }
      }

      throw ApiException(
        statusCode: response.statusCode ?? 0,
        message: 'CoreGrid did not return a valid photo URL.',
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /api/maintenance/faults` — creates a new fault report.
  /// Body: `asset_id`, `description`, `observed_condition`, `photo_url?`.
  Future<FaultReport> reportFault({
    required String assetId,
    required String description,
    required String observedCondition,
    String? photoUrl,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/maintenance/faults',
        data: {
          'asset_id': assetId,
          'description': description.trim(),
          'observed_condition': observedCondition.trim(),
          if (photoUrl != null && photoUrl.isNotEmpty) 'photo_url': photoUrl,
        },
      );
      final data = response.data;
      if (data == null) {
        throw ApiException(
          statusCode: response.statusCode ?? 0,
          message: 'CoreGrid returned an empty response.',
        );
      }
      if (data is Map<String, dynamic>) {
        return FaultReport.fromJson(data);
      }
      return FaultReport(
        id: '',
        assetId: assetId,
        assetCode: '',
        description: description,
        observedCondition: observedCondition,
        status: 'Open',
        reportedAt: DateTime.now(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final maintenanceApiProvider = Provider<MaintenanceApi>((ref) {
  return MaintenanceApi(ref.watch(apiClientProvider));
});
