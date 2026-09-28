import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/api_client.dart';
import '../../shared/api/api_exception.dart';
import 'models/fault_report.dart';
import 'models/maintenance_filter.dart';

/// Every `/api/maintenance` call this feature owns
/// (`mobile-specification.md` §3.1). All failures are normalised to
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
        queryParameters: const {'page': 1, 'pageSize': 50},
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
      // One `photo` part (the action's parameter name), labelled JPEG —
      // pickCompressedPhoto always re-encodes to JPEG, and the API rejects
      // anything but image/jpeg|png|webp.
      final formData = FormData.fromMap({
        'photo': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: DioMediaType('image', 'jpeg'),
        ),
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

  /// `GET /api/maintenance` — FR-042 list/filter/sort/paginate. Readable by
  /// Staff (own department only, server-side), Officer, Auditor, Admin.
  Future<MaintenancePage> listRecords(
    MaintenanceFilter filter, {
    int page = 1,
    int pageSize = MaintenanceFilter.pageSize,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/maintenance',
        queryParameters: filter.toQueryParameters(
          page: page,
          pageSize: pageSize,
        ),
      );
      return MaintenancePage.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /api/maintenance/{id}`.
  Future<FaultReport> getRecord(String id) =>
      _record(() => _dio.get('/api/maintenance/$id'));

  /// `POST /api/maintenance/{id}/start` — FR-037's mobile transition:
  /// APPROVED → IN_PROGRESS (asset goes UNDER_MAINTENANCE). The API rejects
  /// any other starting status with 409 `invalid_status_transition`.
  Future<FaultReport> startWork(String id) =>
      _record(() => _dio.post('/api/maintenance/$id/start'));

  Future<FaultReport> _record(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw ApiException(
          statusCode: response.statusCode ?? 0,
          message: 'CoreGrid returned an empty response.',
        );
      }
      return FaultReport.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final maintenanceApiProvider = Provider<MaintenanceApi>((ref) {
  return MaintenanceApi(ref.watch(apiClientProvider));
});

