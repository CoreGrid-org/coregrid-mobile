import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/api_client.dart';
import '../../shared/api/api_exception.dart';
import 'models/discrepancy.dart';
import 'models/verification_campaign.dart';
import 'models/verification_location.dart';
import 'models/verification_task.dart';

/// Every `/api/verification-tasks` and `/api/discrepancies` call this
/// feature owns (`mobile-specification.md` §3.1). All failures are
/// normalised to [ApiException] so providers/screens never see a raw
/// [DioException] (§3.4).
class VerificationApi {
  VerificationApi(this._dio);

  final Dio _dio;

  /// `GET /api/verification-tasks?mine=&onlyPending=` — ordered by
  /// due date server-side.
  Future<List<VerificationTask>> getTasks({
    bool mine = true,
    bool onlyPending = false,
  }) async {
    try {
      const pageSize = 100;
      final tasks = <VerificationTask>[];
      var page = 1;
      var totalPages = 1;

      do {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/verification-tasks',
          queryParameters: {
            'mine': mine,
            'onlyPending': onlyPending,
            'page': page,
            'pageSize': pageSize,
          },
        );
        final data = response.data;
        if (data == null) return tasks;

        final items = data['items'];
        if (items is! List) {
          throw ApiException(
            statusCode: response.statusCode ?? 0,
            message: 'CoreGrid returned an invalid verification task list.',
          );
        }
        tasks.addAll(
          items.whereType<Map<String, dynamic>>().map(
            VerificationTask.fromJson,
          ),
        );
        totalPages = (data['total_pages'] as num?)?.toInt() ?? page;
        page++;
      } while (page <= totalPages);

      return tasks;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `PATCH /api/verification-tasks/{id}/complete` — asserts
  /// presence/location/condition; the backend auto-raises a discrepancy
  /// as a side effect when the assertion differs from the register.
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

  /// `GET /api/verification-campaigns` — newest first. Read-only: the
  /// create/update/delete/report endpoints are deliberately not wrapped here
  /// (campaign management is React-only, SRS §3.4).
  Future<List<VerificationCampaign>> getCampaigns() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/verification-campaigns',
        queryParameters: {'page': 1, 'pageSize': 100},
      );
      final items = response.data?['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(VerificationCampaign.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /api/verification-campaigns/{id}`.
  Future<VerificationCampaign> getCampaign(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/verification-campaigns/$id',
      );
      final data = response.data;
      if (data == null) {
        throw ApiException(
          statusCode: response.statusCode ?? 0,
          message: 'CoreGrid returned an empty campaign.',
        );
      }
      return VerificationCampaign.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /api/locations` — options for the "asserted location" picker.
  Future<List<VerificationLocation>> getLocations() async {
    try {
      const pageSize = 100;
      final locations = <VerificationLocation>[];
      var page = 1;
      var totalPages = 1;

      do {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/locations',
          queryParameters: {'page': page, 'pageSize': pageSize},
        );
        final data = response.data;
        if (data == null) return locations;

        final items = data['items'];
        if (items is! List) {
          throw ApiException(
            statusCode: response.statusCode ?? 0,
            message: 'CoreGrid returned an invalid location list.',
          );
        }
        locations.addAll(
          items.whereType<Map<String, dynamic>>().map(
            VerificationLocation.fromJson,
          ),
        );
        totalPages = (data['total_pages'] as num?)?.toInt() ?? page;
        page++;
      } while (page <= totalPages);

      return locations;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /api/verification-tasks/photos` — uploads a discrepancy photo
  /// and returns the URL to pass as `photoUrl` to [raiseDiscrepancy].
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

  /// `POST /api/verification-tasks/{taskId}/discrepancies` — raises
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

