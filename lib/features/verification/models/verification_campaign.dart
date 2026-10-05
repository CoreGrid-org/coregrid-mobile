/// Matches the backend's `CampaignDto`. Read-only on mobile — campaign
/// management is React-only (SRS §3.4, "Verification campaign management:
/// React Yes / Flutter No"); the officer sees campaigns only as context for
/// the tasks they perform.
enum CampaignStatus {
  active('Active'),
  completed('Completed'),
  cancelled('Cancelled');

  const CampaignStatus(this.apiValue);

  final String apiValue;

  static CampaignStatus fromApi(String? raw) =>
      values.firstWhere((v) => v.apiValue == raw, orElse: () => active);
}

class VerificationCampaign {
  const VerificationCampaign({
    required this.id,
    required this.name,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    required this.taskCount,
    required this.completedTaskCount,
    required this.openDiscrepancyCount,
    this.scopeDepartmentId,
    this.scopeLocationId,
    this.scopeAssetCategoryId,
    this.scopeAssetTypeId,
    this.scopeDepartmentName,
    this.scopeLocationName,
    this.scopeAssetCategoryName,
    this.scopeAssetTypeName,
  });

  final String id;
  final String name;
  final DateTime periodStart;
  final DateTime periodEnd;
  final CampaignStatus status;
  final int taskCount;
  final int completedTaskCount;
  final int openDiscrepancyCount;
  final String? scopeDepartmentId;
  final String? scopeLocationId;
  final String? scopeAssetCategoryId;
  final String? scopeAssetTypeId;
  final String? scopeDepartmentName;
  final String? scopeLocationName;
  final String? scopeAssetCategoryName;
  final String? scopeAssetTypeName;

  /// 0.0–1.0 share of tasks completed; 0 for a campaign with no tasks.
  double get progress => taskCount == 0 ? 0 : completedTaskCount / taskCount;

  /// Human summary of the campaign's scope filters, e.g.
  /// "Radiology · Ward 3" — or "Whole organisation" when unscoped.
  String get scopeSummary {
    final parts = [
      scopeDepartmentName,
      scopeLocationName,
      scopeAssetCategoryName,
      scopeAssetTypeName,
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? 'Whole organisation' : parts.join(' · ');
  }

  bool get isUnscoped =>
      scopeDepartmentId == null &&
      scopeLocationId == null &&
      scopeAssetCategoryId == null &&
      scopeAssetTypeId == null;

  /// Best-effort scope check by name, for when the scoped asset list
  /// couldn't be loaded in full. The asset record carries no category, so a
  /// category filter can't be judged here and is treated as matching.
  bool scopeMatchesByName({
    required String assetTypeName,
    required String departmentName,
    required String locationName,
  }) {
    bool same(String? scope, String value) =>
        scope == null ||
        scope.isEmpty ||
        scope.trim().toLowerCase() == value.trim().toLowerCase();
    return same(scopeAssetTypeName, assetTypeName) &&
        same(scopeDepartmentName, departmentName) &&
        same(scopeLocationName, locationName);
  }

  factory VerificationCampaign.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return VerificationCampaign(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      status: CampaignStatus.fromApi(json['status'] as String?),
      taskCount: n('task_count'),
      completedTaskCount: n('completed_task_count'),
      openDiscrepancyCount: n('open_discrepancy_count'),
      scopeDepartmentId: json['scope_department_id'] as String?,
      scopeLocationId: json['scope_location_id'] as String?,
      scopeAssetCategoryId: json['scope_asset_category_id'] as String?,
      scopeAssetTypeId: json['scope_asset_type_id'] as String?,
      scopeDepartmentName: json['scope_department_name'] as String?,
      scopeLocationName: json['scope_location_name'] as String?,
      scopeAssetCategoryName: json['scope_asset_category_name'] as String?,
      scopeAssetTypeName: json['scope_asset_type_name'] as String?,
    );
  }
}
