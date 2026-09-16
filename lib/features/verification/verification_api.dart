import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/api_client.dart';
import '../../shared/api/api_exception.dart';
import 'models/discrepancy.dart';
import 'models/verification_location.dart';
import 'models/verification_task.dart';

/// Every `/api/verification-tasks` and `/api/discrepancies` call this
/// feature owns (`MOBILE-SPECIFICATION.md` §3.1). All failures are
/// normalised to [ApiException] so providers/screens never see a raw
/// [DioException] (§3.4).
class VerificationApi {
  VerificationApi(this._dio);

  final Dio _dio;

  /// `GET /api/verification-tasks?mine=&onlyPending=` (FR-058) — ordered by
  /// due date server-side.
  Future<List<VerificationTask>> getTasks({
    bool mine = true,
    bool onlyPending = false,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/api/verification-tasks',
        queryParameters: {'mine': mine, 'onlyPending': onlyPending},
      );
      return (response.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(VerificationTask.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `PATCH /api/verification-tasks/{id}/complete` (FR-059) — asserts
  /// presence/location/condition; the backend auto-raises a discrepancy
  /// (FR-060) as a side effect when the assertion differs from the register.
  Future<VerificationTask> completeTask({
    required String taskId,
    required bool assertedPresent,
    String? assertedLocationId,
    String? assertedCondition,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/verification-tasks/$taskId/complete',
        data: {
          'asserted_present': assertedPresent,
          'asserted_location_id': assertedLocationId,
          'asserted_condition': assertedCondition,
        },
      );
      final data = response.data;
      if (data == null) {
        throw ApiException(
          statusCode: response.statusCode ?? 0,
          message: 'CoreGrid returned an empty response.',
        );
      }
      return VerificationTask.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Returns open discrepancies for the campaign so completion can surface
  /// the automatic discrepancy created by the backend comparison.
  Future<List<Discrepancy>> getOpenDiscrepancies(String campaignId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/api/discrepancies',
        queryParameters: {'campaignId': campaignId, 'onlyOpen': true},
      );
      return (response.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Discrepancy.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /api/locations` — options for the "asserted location" picker.
  Future<List<VerificationLocation>> getLocations() async {
    try {
      final response = await _dio.get<List<dynamic>>('/api/locations');
      return (response.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(VerificationLocation.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /api/verification-tasks/photos` — uploads a discrepancy photo
  /// (already compressed client-side to ≤1MB, IF-11) and returns the URL to
  /// pass as `photoUrl` to [raiseDiscrepancy].
  Future<String> uploadPhoto({
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

  /// `POST /api/verification-tasks/{taskId}/discrepancies` (FR-061) — raises
  /// a discrepancy the automatic comparison can't catch (e.g. Surplus, or
  /// anything needing a photo/description).
  Future<Discrepancy> raiseDiscrepancy({
    required String taskId,
    required DiscrepancyType type,
    required String description,
    String? photoUrl,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/verification-tasks/$taskId/discrepancies',
        data: {
          'type': type.apiValue,
          'description': description.trim(),
          'photo_url': photoUrl,
        },
      );
      final data = response.data;
      if (data == null) {
        throw ApiException(
          statusCode: response.statusCode ?? 0,
          message: 'CoreGrid returned an empty response.',
        );
      }
      return Discrepancy.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final verificationApiProvider = Provider<VerificationApi>((ref) {
  return VerificationApi(ref.watch(apiClientProvider));
});
