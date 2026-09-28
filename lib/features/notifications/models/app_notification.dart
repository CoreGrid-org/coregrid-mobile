/// One in-app notification (`NotificationDto`, FR-080) — the signed-in
/// user's own inbox; the API derives the recipient from the bearer token.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.relatedEntityType,
    this.relatedEntityId,
  });

  final String id;

  /// e.g. `MAINTENANCE_ASSIGNED`, `MAINTENANCE_STATUS_CHANGED`
  /// (backend `Domain/Notifications/NotificationTypes`).
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  /// What the notification is about, for navigation — e.g.
  /// `MaintenanceRecord` + its id.
  final String? relatedEntityType;
  final String? relatedEntityId;

  /// The in-app route for the related record, or null when there's nothing
  /// this app can open for it (the notification is still shown and can be
  /// marked read). Officer-only routes stay guarded by the router.
  String? get route {
    final id = relatedEntityId;
    if (id == null || id.isEmpty) return null;
    return switch (relatedEntityType?.toLowerCase()) {
      'maintenancerecord' || 'maintenance' => '/maintenance/$id',
      'assettransfer' || 'transfer' => '/transfers/$id',
      'agentworkflow' || 'workflow' => '/workflows/$id',
      'asset' => '/assets/$id',
      'verificationtask' => '/verification/$id',
      _ => null,
    };
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    title: title,
    message: message,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    relatedEntityType: relatedEntityType,
    relatedEntityId: relatedEntityId,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id']?.toString() ?? '',
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        isRead: json['is_read'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        relatedEntityType: json['related_entity_type'] as String?,
        relatedEntityId: json['related_entity_id']?.toString(),
      );
}

/// One page of `PagedResult<NotificationDto>`.
class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.page,
    required this.totalPages,
  });

  final List<AppNotification> items;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    return NotificationPage(
      items: items is List
          ? items
                .whereType<Map<String, dynamic>>()
                .map(AppNotification.fromJson)
                .toList()
          : const [],
      page: (json['page'] as num?)?.toInt() ?? 1,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
    );
  }
}
