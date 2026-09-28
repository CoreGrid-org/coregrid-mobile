/// One row of an asset's immutable lifecycle history, from
/// `GET /api/assets/{id}/history`.
class AssetHistoryEntry {
  const AssetHistoryEntry({
    required this.id,
    required this.eventType,
    required this.description,
    required this.createdAt,
    this.actorEmail,
  });

  final String id;
  final String eventType;
  final String description;
  final DateTime createdAt;
  final String? actorEmail;

  factory AssetHistoryEntry.fromJson(Map<String, dynamic> json) {
    return AssetHistoryEntry(
      id: json['id']?.toString() ?? '',
      eventType: json['event_type'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      actorEmail: json['actor_email'] as String?,
    );
  }
}
