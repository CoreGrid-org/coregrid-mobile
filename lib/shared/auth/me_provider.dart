import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import 'auth_controller.dart';

/// The signed-in user's CoreGrid profile (`GET /api/me`, `MeResponse` in the
/// backend) — for the Account tab. Role-gating still uses
/// [AuthController]'s own copy taken at sign-in.
class MeProfile {
  const MeProfile({
    required this.email,
    required this.givenName,
    required this.familyName,
    required this.role,
    required this.organizationName,
    this.departmentId,
  });

  final String email;
  final String givenName;
  final String familyName;
  final String role;
  final String organizationName;

  /// Null for org-wide accounts without a home department.
  final String? departmentId;

  String get fullName => '$givenName $familyName'.trim();

  String get initials {
    final letters = [
      givenName,
      familyName,
    ].where((s) => s.isNotEmpty).map((s) => s[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  String get roleName => roleLabel(role);

  factory MeProfile.fromJson(Map<String, dynamic> json) => MeProfile(
    email: json['email'] as String? ?? '',
    givenName: json['given_name'] as String? ?? '',
    familyName: json['family_name'] as String? ?? '',
    role: json['role'] as String? ?? '',
    organizationName: json['organization_name'] as String? ?? '',
    departmentId: json['department_id'] as String?,
  );
}

final meProvider = FutureProvider.autoDispose<MeProfile>((ref) async {
  try {
    final response = await ref
        .watch(apiClientProvider)
        .get<Map<String, dynamic>>('/api/me');
    return MeProfile.fromJson(response.data ?? const {});
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
});

/// The user's department and the locations in it. Staff data is scoped to
/// this department by the API itself (`DepartmentScope`, SRS §4.6) — the
/// app only *shows* it and narrows Staff pickers to it; it never filters
/// server results client-side (AR-1).
class Workplace {
  const Workplace({
    required this.departmentId,
    required this.departmentName,
    required this.locations,
  });

  final String departmentId;
  final String departmentName;
  final List<String> locations;
}

final myWorkplaceProvider = FutureProvider.autoDispose<Workplace?>((ref) async {
  final me = await ref.watch(meProvider.future);
  final departmentId = me.departmentId;
  if (departmentId == null) return null;

  final dio = ref.watch(apiClientProvider);
  try {
    final [departments, locations] = await Future.wait([
      dio.get<Map<String, dynamic>>(
        '/api/departments',
        queryParameters: {'pageSize': 100},
      ),
      dio.get<Map<String, dynamic>>(
        '/api/locations',
        queryParameters: {'departmentId': departmentId, 'pageSize': 100},
      ),
    ], eagerError: true);
    List<Map<String, dynamic>> items(Response<Map<String, dynamic>> r) =>
        ((r.data?['items'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();

    final department = items(departments)
        .where((d) => d['id'] == departmentId)
        .firstOrNull;
    return Workplace(
      departmentId: departmentId,
      departmentName: department?['name'] as String? ?? 'Your department',
      locations: [
        for (final l in items(locations))
          if (l['name'] case final String name) name,
      ],
    );
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
});
