/// Wire models for `GET /api/departments` and `GET /api/locations`
/// (`backend/Features/OrgConfig/DTOs/DepartmentDto.cs`,
/// `LocationDto.cs`). Both endpoints are readable by InventoryOfficer
/// (confirmed from `DepartmentsController.cs` / `LocationsController.cs`
/// `ReadRoles` constant).
class DepartmentDto {
  const DepartmentDto({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
  });

  final String id;
  final String code;
  final String name;
  final bool isActive;

  factory DepartmentDto.fromJson(Map<String, dynamic> json) => DepartmentDto(
        id: json['id']?.toString() ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
      );
}

/// `LocationDto` — locations are always scoped to a department on the
/// backend (`GET /api/locations?department_id=<guid>`), so the picker
/// must cascade: pick department first, then load matching locations.
class LocationDto {
  const LocationDto({
    required this.id,
    required this.name,
    required this.type,
    required this.departmentId,
    required this.departmentName,
    required this.isActive,
  });

  final String id;
  final String name;
  final String type;
  final String departmentId;
  final String departmentName;
  final bool isActive;

  factory LocationDto.fromJson(Map<String, dynamic> json) => LocationDto(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? '',
        departmentId: json['department_id']?.toString() ?? '',
        departmentName: json['department_name'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
      );
}
