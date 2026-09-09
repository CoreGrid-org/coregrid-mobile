import 'asset_condition.dart';
import 'asset_detail.dart';

class AssetSearchQuery {
  const AssetSearchQuery({
    this.search = '',
    this.department = '',
    this.location = '',
    this.category = '',
    this.assetType = '',
    this.status = '',
    this.condition = '',
    this.sortBy = 'name',
    this.sortOrder = 'asc',
    this.page = 1,
    this.pageSize = 20,
  });

  final String search;
  final String department;
  final String location;
  final String category;
  final String assetType;
  final String status;
  final String condition;
  final String sortBy;
  final String sortOrder;
  final int page;
  final int pageSize;

  AssetSearchQuery copyWith({int? page}) => AssetSearchQuery(
    search: search,
    department: department,
    location: location,
    category: category,
    assetType: assetType,
    status: status,
    condition: condition,
    sortBy: sortBy,
    sortOrder: sortOrder,
    page: page ?? this.page,
    pageSize: pageSize,
  );

  Map<String, dynamic> toQueryParameters() => {
    if (search.trim().isNotEmpty) 'search': search.trim(),
    if (department.trim().isNotEmpty) 'department': department.trim(),
    if (location.trim().isNotEmpty) 'location': location.trim(),
    if (category.trim().isNotEmpty) 'category': category.trim(),
    if (assetType.trim().isNotEmpty) 'asset_type': assetType.trim(),
    if (status.trim().isNotEmpty) 'status': status.trim(),
    if (condition.trim().isNotEmpty) 'condition': condition.trim(),
    'sort_by': sortBy,
    'sort_order': sortOrder,
    'page': page,
    'page_size': pageSize,
  };

  @override
  bool operator ==(Object other) =>
      other is AssetSearchQuery &&
      other.search == search &&
      other.department == department &&
      other.location == location &&
      other.category == category &&
      other.assetType == assetType &&
      other.status == status &&
      other.condition == condition &&
      other.sortBy == sortBy &&
      other.sortOrder == sortOrder &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(
    search,
    department,
    location,
    category,
    assetType,
    status,
    condition,
    sortBy,
    sortOrder,
    page,
    pageSize,
  );
}

class AssetSearchResult {
  const AssetSearchResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  final List<AssetDetail> items;
  final int page;
  final int pageSize;
  final int totalCount;

  int get pageCount => totalCount == 0 ? 1 : (totalCount / pageSize).ceil();

  factory AssetSearchResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] ?? json['data'] ?? const [];
    final items = rawItems is List
        ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(AssetDetail.fromJson)
              .toList()
        : const <AssetDetail>[];
    return AssetSearchResult(
      items: items,
      page: _int(json['page']) ?? 1,
      pageSize: _int(json['page_size'] ?? json['pageSize']) ?? 20,
      totalCount:
          _int(json['total_count'] ?? json['totalCount'] ?? json['count']) ??
          items.length,
    );
  }

  static int? _int(Object? value) => switch (value) {
    int value => value,
    num value => value.toInt(),
    String value => int.tryParse(value),
    _ => null,
  };
}

String conditionLabel(String raw) =>
    AssetCondition.tryParse(raw)?.label ?? (raw.isEmpty ? 'Unknown' : raw);