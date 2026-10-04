/// Response returned by `POST /api/assets/{id}/condemn` (FR-049).
class CondemnAssetResponse {
  const CondemnAssetResponse({
    required this.assetId,
    required this.assetCode,
    required this.name,
    required this.status,
    required this.condition,
    this.reason,
    required this.condemnedAt,
  });

  final String assetId;
  final String assetCode;
  final String name;
  final String status;
  final String condition;
  final String? reason;
  final DateTime condemnedAt;

  factory CondemnAssetResponse.fromJson(Map<String, dynamic> json) {
    return CondemnAssetResponse(
      assetId: json['asset_id']?.toString() ?? '',
      assetCode: json['asset_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      condition: json['condition'] as String? ?? '',
      reason: json['reason'] as String?,
      condemnedAt:
          DateTime.tryParse(json['condemned_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
