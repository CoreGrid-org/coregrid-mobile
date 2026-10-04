/// Payload for `POST /api/assets/{id}/condemn` (FR-049).
class CondemnAssetRequest {
  const CondemnAssetRequest({
    this.reason,
    this.evidenceUrl,
  });

  /// Officer's justification (max 1000 chars per backend model validation).
  final String? reason;

  /// Private object-storage key or URL to photo/report evidence (max 2000 chars).
  final String? evidenceUrl;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (reason != null && reason!.trim().isNotEmpty) {
      map['reason'] = reason!.trim();
    }
    if (evidenceUrl != null && evidenceUrl!.trim().isNotEmpty) {
      map['evidence_url'] = evidenceUrl!.trim();
    }
    return map;
  }
}
