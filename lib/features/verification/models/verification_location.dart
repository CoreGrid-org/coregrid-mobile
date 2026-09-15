/// A location option for the "asserted location" picker on the task
/// completion screen — matches `LocationDto`
/// (`CoreGrid/backend/Features/OrgConfig/DTOs/LocationDto.cs`). Kept
/// minimal and local to this feature rather than a full org-config model.
class VerificationLocation {
  const VerificationLocation({
    required this.id,
    required this.name,
    required this.departmentName,
  });

  final String id;
  final String name;
  final String departmentName;

  factory VerificationLocation.fromJson(Map<String, dynamic> json) {
    return VerificationLocation(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      departmentName: json['department_name'] as String? ?? '',
    );
  }
}
