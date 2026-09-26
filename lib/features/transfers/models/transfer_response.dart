/// Wire model for `TransferResponse` (`backend/Features/Transfers/DTOs/
/// TransferDtos.cs`). Field names match the backend's
/// `JsonNamingPolicy.SnakeCaseLower` policy. Enum values are the C#
/// identifier strings produced by `JsonStringEnumConverter`
/// (e.g. `"IN_TRANSIT"`, not `"in_transit"`).
class TransferResponse {
  const TransferResponse({
    required this.id,
    required this.assetId,
    required this.assetCode,
    required this.assetName,
    required this.statusRaw,
    required this.requestedAt,
    this.fromDepartmentName,
    this.toDepartmentName,
    this.fromLocationName,
    this.toLocationName,
    this.initiatedByUserEmail,
    this.approvedByUserEmail,
    this.confirmedByUserEmail,
    this.approvedAt,
    this.confirmedAt,
    this.rejectionReason,
  });

  final String id;
  final String assetId;
  final String assetCode;
  final String assetName;

  final String? fromDepartmentName;
  final String? toDepartmentName;
  final String? fromLocationName;
  final String? toLocationName;

  final String? initiatedByUserEmail;
  final String? approvedByUserEmail;
  final String? confirmedByUserEmail;

  /// Raw status string from the API — use [status] for the typed value.
  final String statusRaw;

  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? confirmedAt;

  final String? rejectionReason;

  TransferStatus get status => TransferStatus.fromApi(statusRaw);

  factory TransferResponse.fromJson(Map<String, dynamic> json) {
    return TransferResponse(
      id: json['id']?.toString() ?? '',
      assetId: json['asset_id']?.toString() ?? '',
      assetCode: json['asset_code'] as String? ?? '',
      assetName: json['asset_name'] as String? ?? '',
      fromDepartmentName: json['from_department_name'] as String?,
      toDepartmentName: json['to_department_name'] as String?,
      fromLocationName: json['from_location_name'] as String?,
      toLocationName: json['to_location_name'] as String?,
      initiatedByUserEmail: json['initiated_by_user_email'] as String?,
      approvedByUserEmail: json['approved_by_user_email'] as String?,
      confirmedByUserEmail: json['confirmed_by_user_email'] as String?,
      statusRaw: json['status'] as String? ?? '',
      requestedAt:
          DateTime.tryParse(json['requested_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'] as String)
          : null,
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.tryParse(json['confirmed_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }
}

/// Transfer lifecycle states (`backend/Domain/AssetTransfer.cs`
/// `enum TransferStatus`). Serialised as the C# identifier string by
/// `JsonStringEnumConverter`. [unknown] keeps the client forward-compatible
/// if the backend adds a state.
enum TransferStatus {
  requested('REQUESTED', 'Requested'),
  approved('APPROVED', 'Approved'),
  inTransit('IN_TRANSIT', 'In Transit'),
  completed('COMPLETED', 'Completed'),
  rejected('REJECTED', 'Rejected'),
  cancelled('CANCELLED', 'Cancelled'),
  unknown('', 'Unknown');

  const TransferStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static TransferStatus fromApi(String raw) {
    final normalized = raw.trim().toUpperCase();
    for (final s in TransferStatus.values) {
      if (s.apiValue == normalized && s != unknown) return s;
    }
    return unknown;
  }
}
