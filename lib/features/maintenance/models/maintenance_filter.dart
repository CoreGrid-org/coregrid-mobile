import 'package:intl/intl.dart';

import 'fault_report.dart';

/// `MaintenanceStatus` (backend `Domain/Maintenance/MaintenanceRecord.cs`).
enum MaintenanceStatus {
  requested('REQUESTED', 'Requested'),
  approved('APPROVED', 'Approved'),
  inProgress('IN_PROGRESS', 'In progress'),
  completed('COMPLETED', 'Completed'),
  cancelled('CANCELLED', 'Cancelled');

  const MaintenanceStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// `MaintenancePriority`.
enum MaintenancePriority {
  low('LOW', 'Low'),
  medium('MEDIUM', 'Medium'),
  high('HIGH', 'High'),
  critical('CRITICAL', 'Critical');

  const MaintenancePriority(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// `MaintenanceType`.
enum MaintenanceType {
  corrective('CORRECTIVE', 'Corrective'),
  preventive('PREVENTIVE', 'Preventive');

  const MaintenanceType(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// Sort keys the API's `SortMap` accepts (lower-case, exact).
enum MaintenanceSort {
  newest('createdat', 'Newest first', descending: true),
  oldest('createdat', 'Oldest first', descending: false),
  priority('priority', 'Highest priority', descending: true),
  status('status', 'Status', descending: false);

  const MaintenanceSort(this.apiKey, this.label, {required this.descending});

  final String apiKey;
  final String label;
  final bool descending;
}

/// FR-042's filters for `GET /api/maintenance` (`MaintenanceRecordFilter`):
/// status, priority, type, department, asset, assignee and date range, plus
/// sort. Immutable with value equality so it can key a provider family.
class MaintenanceFilter {
  const MaintenanceFilter({
    this.status,
    this.priority,
    this.type,
    this.departmentId,
    this.departmentName,
    this.assetId,
    this.assetCode,
    this.assigneeId,
    this.dateFrom,
    this.dateTo,
    this.sort = MaintenanceSort.newest,
  });

  static const pageSize = 20;

  final MaintenanceStatus? status;
  final MaintenancePriority? priority;
  final MaintenanceType? type;
  final String? departmentId;

  /// Display only — the API filters by [departmentId].
  final String? departmentName;
  final String? assetId;

  /// Display only — the API filters by [assetId].
  final String? assetCode;

  /// Set to the signed-in user's id for "Assigned to me".
  final String? assigneeId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final MaintenanceSort sort;

  /// Filters other than sort that are set — for the "Filters (n)" badge.
  int get activeCount => [
    status,
    priority,
    type,
    departmentId,
    assetId,
    assigneeId,
    dateFrom ?? dateTo,
  ].whereType<Object>().length;

  /// camelCase keys — ASP.NET binds `[FromQuery]` by property name.
  Map<String, dynamic> toQueryParameters({
    required int page,
    required int pageSize,
  }) {
    final day = DateFormat('yyyy-MM-dd');
    return {
      'status': ?status?.apiValue,
      'priority': ?priority?.apiValue,
      'type': ?type?.apiValue,
      'departmentId': ?departmentId,
      'assetId': ?assetId,
      'assigneeId': ?assigneeId,
      if (dateFrom != null) 'dateFrom': day.format(dateFrom!),
      if (dateTo != null) 'dateTo': day.format(dateTo!),
      'sortBy': sort.apiKey,
      'sortDirection': sort.descending ? 'desc' : 'asc',
      'page': page,
      'pageSize': pageSize,
    };
  }

  MaintenanceFilter copyWith({
    MaintenanceStatus? Function()? status,
    MaintenancePriority? Function()? priority,
    MaintenanceType? Function()? type,
    ({String id, String name})? Function()? department,
    ({String id, String code})? Function()? asset,
    String? Function()? assigneeId,
    ({DateTime from, DateTime to})? Function()? dateRange,
    MaintenanceSort? sort,
  }) {
    final dept = department != null ? department() : null;
    final a = asset != null ? asset() : null;
    final range = dateRange != null ? dateRange() : null;
    return MaintenanceFilter(
      status: status != null ? status() : this.status,
      priority: priority != null ? priority() : this.priority,
      type: type != null ? type() : this.type,
      departmentId: department != null ? dept?.id : departmentId,
      departmentName: department != null ? dept?.name : departmentName,
      assetId: asset != null ? a?.id : assetId,
      assetCode: asset != null ? a?.code : assetCode,
      assigneeId: assigneeId != null ? assigneeId() : this.assigneeId,
      dateFrom: dateRange != null ? range?.from : dateFrom,
      dateTo: dateRange != null ? range?.to : dateTo,
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MaintenanceFilter &&
      other.status == status &&
      other.priority == priority &&
      other.type == type &&
      other.departmentId == departmentId &&
      other.assetId == assetId &&
      other.assigneeId == assigneeId &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(
    status,
    priority,
    type,
    departmentId,
    assetId,
    assigneeId,
    dateFrom,
    dateTo,
    sort,
  );
}

/// One page of `PagedResult<MaintenanceRecordDto>`.
class MaintenancePage {
  const MaintenancePage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.totalPages,
  });

  final List<FaultReport> items;
  final int totalCount;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory MaintenancePage.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    int read(String key) => (json[key] as num?)?.toInt() ?? 0;
    return MaintenancePage(
      items: items is List
          ? items
                .whereType<Map<String, dynamic>>()
                .map(FaultReport.fromJson)
                .toList()
          : const [],
      totalCount: read('total_count'),
      page: read('page'),
      totalPages: read('total_pages'),
    );
  }
}
