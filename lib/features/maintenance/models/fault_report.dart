/// A maintenance record (`MaintenanceRecordDto`) — what a fault report
/// becomes once raised (FR-033), and what the maintenance list (FR-042) and
/// progress update (FR-037) work on.
class FaultReport {
  const FaultReport({
    required this.id,
    required this.assetId,
    required this.assetCode,
    required this.description,
    required this.observedCondition,
    required this.status,
    required this.reportedAt,
    this.photoUrl,
    this.reportedByEmail,
    this.reportedByName,
    this.createdById,
    this.type,
    this.assetName,
    this.priority,
    this.assigneeId,
    this.assigneeEmail,
    this.estimatedCost,
    this.actualCost,
    this.workPerformed,
    this.completionDate,
    this.resultingCondition,
    this.cancellationReason,
  });

  final String id;
  final String assetId;
  final String assetCode;
  final String description;
  final String observedCondition;
  final String status;
  final DateTime reportedAt;
  final String? photoUrl;
  final String? reportedByEmail;
  final String? reportedByName;
  final String? createdById;
  final String? type;
  final String? assetName;

  /// LOW / MEDIUM / HIGH / CRITICAL.
  final String? priority;
  final String? assigneeId;
  final String? assigneeEmail;
  final num? estimatedCost;
  final num? actualCost;
  final String? workPerformed;
  final DateTime? completionDate;
  final String? resultingCondition;
  final String? cancellationReason;

  /// Whether this record is an automated/system scheduled preventive maintenance task.
  bool get isPreventive {
    final t = type?.toUpperCase() ?? '';
    final d = description.toLowerCase();
    return t == 'PREVENTIVE' ||
        t == 'SCHEDULED' ||
        d.startsWith('scheduled preventive') ||
        d.contains('preventive maintenance (interval:');
  }

  /// `IN_PROGRESS`, `in progress`, `InProgress` → `IN_PROGRESS`-ish key.
  String get _statusKey =>
      status.trim().toUpperCase().replaceAll(' ', '_').replaceAll('-', '_');

  bool get isOpen => const {
    'OPEN',
    'REPORTED',
    'REQUESTED',
    'PENDING',
    'NEW',
  }.contains(_statusKey);

  /// Approved or being worked on — still active, past the request stage.
  bool get isInProgress => isApproved || isUnderWay;

  /// APPROVED: assigned and costed, work not yet started.
  bool get isApproved => const {'APPROVED', 'ACCEPTED'}.contains(_statusKey);

  /// IN_PROGRESS: work started, asset UNDER_MAINTENANCE.
  bool get isUnderWay => const {
    'IN_PROGRESS',
    'INPROGRESS',
    'ASSIGNED',
    'UNDER_MAINTENANCE',
    'MAINTENANCE',
    'ONGOING',
    'ON_HOLD',
    'ONHOLD',
    'HOLD',
  }.contains(_statusKey);

  bool get isCancelled => const {
    'CANCELLED',
    'CANCELED',
    'REJECTED',
    'DECLINED',
  }.contains(_statusKey);

  /// `AST-0042 · Forklift`, or whichever half is known.
  String get assetLabel =>
      [assetCode, ?assetName].where((s) => s.isNotEmpty).toSet().join(' · ');

  String get statusLabel {
    switch (_statusKey) {
      case 'OPEN':
      case 'REPORTED':
      case 'PENDING':
      case 'REQUESTED':
      case 'NEW':
        return 'Requested';
      case 'APPROVED':
      case 'ACCEPTED':
        return 'Approved';
      case 'INPROGRESS':
      case 'IN_PROGRESS':
      case 'ASSIGNED':
      case 'UNDER_MAINTENANCE':
      case 'MAINTENANCE':
      case 'ONGOING':
        return 'In Progress';
      case 'ON_HOLD':
      case 'ONHOLD':
      case 'HOLD':
        return 'On Hold';
      case 'COMPLETED':
      case 'RESOLVED':
      case 'FIXED':
      case 'REPAIRED':
        return 'Resolved';
      case 'REJECTED':
      case 'DECLINED':
      case 'CANCELLED':
      case 'CANCELED':
        return 'Rejected';
      case 'CLOSED':
        return 'Closed';
      default:
        return status.isNotEmpty ? status : 'Requested';
    }
  }

  static String _intToStatus(int val) {
    switch (val) {
      case 0:
        return 'Requested';
      case 1:
        return 'Approved';
      case 2:
        return 'InProgress';
      case 3:
        return 'OnHold';
      case 4:
        return 'Resolved';
      case 5:
        return 'Closed';
      case 6:
        return 'Rejected';
      default:
        return 'Requested';
    }
  }

  factory FaultReport.fromJson(Map<String, dynamic> json) {
    final rawStatus =
        json['status'] ??
        json['Status'] ??
        json['state'] ??
        json['State'] ??
        json['maintenance_status'] ??
        json['maintenanceStatus'] ??
        json['fault_status'] ??
        json['faultStatus'] ??
        json['status_name'] ??
        json['statusName'] ??
        json['status_label'] ??
        json['statusLabel'];
    final statusStr = rawStatus is int
        ? _intToStatus(rawStatus)
        : (rawStatus?.toString() ?? 'Requested');

    final assetObj = json['asset'] is Map ? json['asset'] as Map : null;
    final assetCodeVal =
        (json['asset_code'] ??
                json['assetCode'] ??
                json['AssetCode'] ??
                json['asset_tag'] ??
                json['assetTag'] ??
                assetObj?['asset_code'] ??
                assetObj?['assetCode'] ??
                assetObj?['code'] ??
                assetObj?['tag'] ??
                assetObj?['name'] ??
                json['asset_name'] ??
                json['assetName'] ??
                json['asset_id'] ??
                json['assetId'] ??
                '')
            .toString();

    final dateStr =
        (json['reported_at'] ??
                json['reportedAt'] ??
                json['ReportedAt'] ??
                json['created_at'] ??
                json['createdAt'] ??
                json['CreatedAt'] ??
                json['request_date'] ??
                json['requestDate'] ??
                json['date'] ??
                json['Date'])
            ?.toString();

    final userObj =
        (json['user'] is Map ? json['user'] as Map : null) ??
        (json['requester'] is Map ? json['requester'] as Map : null) ??
        (json['reported_by'] is Map ? json['reported_by'] as Map : null) ??
        (json['reportedBy'] is Map ? json['reportedBy'] as Map : null) ??
        (json['requested_by'] is Map ? json['requested_by'] as Map : null) ??
        (json['requestedBy'] is Map ? json['requestedBy'] as Map : null) ??
        (json['creator'] is Map ? json['creator'] as Map : null) ??
        (json['created_by'] is Map ? json['created_by'] as Map : null) ??
        (json['createdBy'] is Map ? json['createdBy'] as Map : null);

    final emailVal =
        json['reported_by_email'] ??
        json['reportedByEmail'] ??
        json['ReportedByEmail'] ??
        json['requester_email'] ??
        json['requesterEmail'] ??
        json['RequesterEmail'] ??
        json['requested_by_email'] ??
        json['requestedByEmail'] ??
        json['created_by_email'] ??
        json['createdByEmail'] ??
        json['user_email'] ??
        json['userEmail'] ??
        userObj?['email'] ??
        userObj?['Email'] ??
        (json['reported_by'] is String ? json['reported_by'] : null) ??
        (json['reportedBy'] is String ? json['reportedBy'] : null) ??
        (json['requester'] is String ? json['requester'] : null);

    final nameVal =
        json['reported_by_name'] ??
        json['reportedByName'] ??
        json['requester_name'] ??
        json['requesterName'] ??
        json['requested_by_name'] ??
        json['requestedByName'] ??
        json['created_by_name'] ??
        json['createdByName'] ??
        json['user_name'] ??
        json['userName'] ??
        userObj?['name'] ??
        userObj?['given_name'] ??
        userObj?['displayName'] ??
        userObj?['userName'];

    final idVal =
        json['created_by_id'] ??
        json['createdById'] ??
        json['CreatedById'] ??
        json['requester_id'] ??
        json['requesterId'] ??
        json['RequesterId'] ??
        json['requested_by_id'] ??
        json['requestedById'] ??
        json['user_id'] ??
        json['userId'] ??
        json['UserId'] ??
        userObj?['id'] ??
        userObj?['Id'] ??
        userObj?['userId'] ??
        (json['created_by'] is String ? json['created_by'] : null) ??
        (json['createdBy'] is String ? json['createdBy'] : null);

    return FaultReport(
      id:
          (json['id'] ??
                  json['Id'] ??
                  json['fault_id'] ??
                  json['faultId'] ??
                  json['FaultId'] ??
                  json['maintenance_id'] ??
                  json['maintenanceId'] ??
                  json['MaintenanceId'])
              ?.toString() ??
          '',
      assetId:
          (json['asset_id'] ??
                  json['assetId'] ??
                  json['AssetId'] ??
                  assetObj?['id'] ??
                  assetObj?['Id'])
              ?.toString() ??
          '',
      assetCode: assetCodeVal,
      description:
          (json['description'] ??
                  json['Description'] ??
                  json['fault_description'] ??
                  json['faultDescription'] ??
                  json['title'] ??
                  json['Title'])
              ?.toString() ??
          '',
      observedCondition:
          (json['observed_condition'] ??
                  json['observedCondition'] ??
                  json['ObservedCondition'] ??
                  json['condition'] ??
                  json['Condition'])
              ?.toString() ??
          '',
      status: statusStr,
      reportedAt: DateTime.tryParse(dateStr ?? '') ?? DateTime.now(),
      photoUrl: (json['photo_url'] ?? json['photoUrl'] ?? json['PhotoUrl'])
          ?.toString(),
      reportedByEmail: emailVal?.toString(),
      reportedByName: nameVal?.toString(),
      createdById: idVal?.toString(),
      type:
          (json['type'] ??
                  json['Type'] ??
                  json['maintenance_type'] ??
                  json['maintenanceType'] ??
                  json['MaintenanceType'])
              ?.toString(),
      assetName: _str(
        json['asset_name'] ?? json['assetName'] ?? assetObj?['name'],
      ),
      priority: _str(json['priority'] ?? json['Priority']),
      assigneeId: _str(json['assignee_id'] ?? json['assigneeId']),
      assigneeEmail: _str(json['assignee_email'] ?? json['assigneeEmail']),
      estimatedCost: _num(json['estimated_cost'] ?? json['estimatedCost']),
      actualCost: _num(json['actual_cost'] ?? json['actualCost']),
      workPerformed: _str(json['work_performed'] ?? json['workPerformed']),
      completionDate: DateTime.tryParse(
        _str(json['completion_date'] ?? json['completionDate']) ?? '',
      ),
      resultingCondition: _str(
        json['resulting_condition'] ?? json['resultingCondition'],
      ),
      cancellationReason: _str(
        json['cancellation_reason'] ?? json['cancellationReason'],
      ),
    );
  }

  static String? _str(Object? v) {
    final s = v?.toString();
    return s == null || s.isEmpty ? null : s;
  }

  static num? _num(Object? v) => v is num ? v : num.tryParse('${v ?? ''}');
}
