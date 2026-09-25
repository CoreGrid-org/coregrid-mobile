/// FaultReport DTO, mirrors maintenance API responses.
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

  /// Whether this record is an automated/system scheduled preventive maintenance task.
  bool get isPreventive {
    final t = type?.toUpperCase() ?? '';
    final d = description.toLowerCase();
    return t == 'PREVENTIVE' ||
        t == 'SCHEDULED' ||
        d.startsWith('scheduled preventive') ||
        d.contains('preventive maintenance (interval:');
  }

  bool get isOpen =>
      status.toLowerCase() == 'open' ||
      status.toLowerCase() == 'reported' ||
      status.toLowerCase() == 'requested' ||
      status.toLowerCase() == 'pending';

  bool get isInProgress =>
      status.toLowerCase() == 'inprogress' ||
      status.toLowerCase() == 'in progress' ||
      status.toLowerCase() == 'assigned' ||
      status.toLowerCase() == 'under_maintenance' ||
      status.toLowerCase() == 'approved';

  String get statusLabel {
    final s = status
        .trim()
        .toUpperCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_');
    switch (s) {
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
    );
  }
}
