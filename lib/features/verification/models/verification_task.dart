/// FR-058/FR-059 — a task within a verification campaign, assigned to an
/// officer. Matches `VerificationTaskDto`
/// (`CoreGrid/backend/Features/Verification/DTOs/VerificationTaskDto.cs`).
enum VerificationTaskStatus {
  pending('Pending'),
  completed('Completed');

  const VerificationTaskStatus(this.apiValue);

  final String apiValue;

  static VerificationTaskStatus fromApi(String? raw) =>
      values.firstWhere((v) => v.apiValue == raw, orElse: () => pending);
}

/// The five-point condition scale the backend validates against
/// (`VerificationTaskService.ValidConditions`) — kept local to this feature
/// rather than shared with `features/assets/` (§3.1: a feature owns its own
/// models).
enum ObservedCondition {
  brandNew('NEW', 'New'),
  good('GOOD', 'Good'),
  fair('FAIR', 'Fair'),
  poor('POOR', 'Poor'),
  unserviceable('UNSERVICEABLE', 'Unserviceable');

  const ObservedCondition(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ObservedCondition? tryParse(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().toUpperCase();
    for (final c in values) {
      if (c.apiValue == normalized) return c;
    }
    return null;
  }
}

class VerificationTask {
  const VerificationTask({
    required this.id,
    required this.campaignId,
    required this.campaignName,
    required this.assetId,
    required this.assetCode,
    required this.assetName,
    this.assignedToUserId,
    this.assignedToEmail,
    required this.dueDate,
    required this.status,
    this.assertedPresent,
    this.assertedLocationId,
    this.assertedCondition,
    this.completedAt,
  });

  final String id;
  final String campaignId;
  final String campaignName;
  final String assetId;
  final String assetCode;
  final String assetName;
  final String? assignedToUserId;
  final String? assignedToEmail;
  final DateTime dueDate;
  final VerificationTaskStatus status;
  final bool? assertedPresent;
  final String? assertedLocationId;
  final String? assertedCondition;
  final DateTime? completedAt;

  bool get isPending => status == VerificationTaskStatus.pending;

  /// Due-date-passed, still-pending — drives the task list's overdue styling
  /// (FR-058 orders by due date; the SRS doesn't otherwise define
  /// "overdue", so this is the plain calendar-date interpretation).
  bool get isOverdue {
    if (!isPending) return false;
    final today = DateTime.now();
    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    return dueDateOnly.isBefore(todayOnly);
  }

  factory VerificationTask.fromJson(Map<String, dynamic> json) {
    return VerificationTask(
      id: json['id'] as String,
      campaignId: json['campaign_id'] as String? ?? '',
      campaignName: json['campaign_name'] as String? ?? '',
      assetId: json['asset_id'] as String? ?? '',
      assetCode: json['asset_code'] as String? ?? '',
      assetName: json['asset_name'] as String? ?? '',
      assignedToUserId: json['assigned_to_user_id'] as String?,
      assignedToEmail: json['assigned_to_email'] as String?,
      dueDate: DateTime.parse(json['due_date'] as String),
      status: VerificationTaskStatus.fromApi(json['status'] as String?),
      assertedPresent: json['asserted_present'] as bool?,
      assertedLocationId: json['asserted_location_id'] as String?,
      assertedCondition: json['asserted_condition'] as String?,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }
}
