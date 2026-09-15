/// FR-060/FR-061 — matches `DiscrepancyDto`
/// (`CoreGrid/backend/Features/Verification/DTOs/DiscrepancyDto.cs`).
/// `Surplus` and `DataMismatch` are deliberately included even though this
/// app only raises discrepancies manually (never automatically) — the
/// backend accepts any classification from a manual raise, only the
/// automatic path (`VerificationTaskService`) is restricted to the three it
/// can derive from an assertion.
enum DiscrepancyType {
  missing('Missing', 'Missing'),
  surplus('Surplus', 'Surplus (unregistered asset found)'),
  locationMismatch('LocationMismatch', 'Location mismatch'),
  conditionMismatch('ConditionMismatch', 'Condition mismatch'),
  dataMismatch('DataMismatch', 'Data mismatch'),
  other('Other', 'Other');

  const DiscrepancyType(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class Discrepancy {
  const Discrepancy({
    required this.id,
    required this.campaignId,
    required this.verificationTaskId,
    required this.assetId,
    required this.assetCode,
    required this.type,
    required this.isAutomatic,
    this.raisedByUserId,
    this.raisedByEmail,
    required this.description,
    this.photoUrl,
    required this.status,
    this.resolutionType,
    required this.createdAt,
  });

  final String id;
  final String campaignId;
  final String verificationTaskId;
  final String assetId;
  final String assetCode;
  final String type;
  final bool isAutomatic;
  final String? raisedByUserId;
  final String? raisedByEmail;
  final String description;
  final String? photoUrl;
  final String status;
  final String? resolutionType;
  final DateTime createdAt;

  bool get isOpen => status == 'Open';

  factory Discrepancy.fromJson(Map<String, dynamic> json) {
    return Discrepancy(
      id: json['id'] as String,
      campaignId: json['campaign_id'] as String? ?? '',
      verificationTaskId: json['verification_task_id'] as String? ?? '',
      assetId: json['asset_id'] as String? ?? '',
      assetCode: json['asset_code'] as String? ?? '',
      type: json['type'] as String? ?? 'Other',
      isAutomatic: json['is_automatic'] as bool? ?? false,
      raisedByUserId: json['raised_by_user_id'] as String?,
      raisedByEmail: json['raised_by_email'] as String?,
      description: json['description'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      status: json['status'] as String? ?? 'Open',
      resolutionType: json['resolution_type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
