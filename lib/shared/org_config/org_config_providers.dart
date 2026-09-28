import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import 'org_config_models.dart';

/// API client for `GET /api/departments` and `GET /api/locations`
/// (`backend/Features/OrgConfig/`). Follows the same pattern as
/// `AssetsApi` — takes the shared Dio instance, wraps failures in
/// [ApiException], never constructs its own Dio.
///
/// Both endpoints are org-scoped server-side; no org filter is needed
/// on the client. Inactive departments / locations are excluded so pickers
/// only offer valid destinations. Query parameters are camelCase — ASP.NET
/// binds `[FromQuery]` by property name, and 100 is the API's page cap.
class OrgConfigApi {
  OrgConfigApi(this._dio);

  final Dio _dio;

  /// `GET /api/departments` — returns all active departments in the
  /// current user's organisation. InventoryOfficer has read access.
  Future<List<DepartmentDto>> getDepartments() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/departments',
        queryParameters: {'includeInactive': false, 'pageSize': 100},
      );
      final items = response.data?['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(DepartmentDto.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /api/locations?departmentId=<id>` — returns active locations
  /// for the given department. Cascade: call after the user picks a
  /// department.
  Future<List<LocationDto>> getLocationsForDepartment(
    String departmentId,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/locations',
        queryParameters: {
          'departmentId': departmentId,
          'includeInactive': false,
          'pageSize': 100,
        },
      );
      final items = response.data?['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(LocationDto.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final orgConfigApiProvider = Provider<OrgConfigApi>(
  (ref) => OrgConfigApi(ref.watch(apiClientProvider)),
);

/// Active departments — loaded once per session (no autoDispose) since the
/// list changes rarely and is reused across the transfer form.
final departmentsProvider = FutureProvider<List<DepartmentDto>>((ref) {
  return ref.watch(orgConfigApiProvider).getDepartments();
});

/// Locations for a specific department, keyed by department id. autoDispose
/// so switching departments drops the old list rather than serving stale data.
final locationsForDepartmentProvider = FutureProvider.autoDispose
    .family<List<LocationDto>, String>((ref, departmentId) {
      return ref
          .watch(orgConfigApiProvider)
          .getLocationsForDepartment(departmentId);
    });
