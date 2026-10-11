/// An asset type a fleet evaluation can target — `AssetTypeDto` from
/// `GET /api/asset-types`. Each type carries its category, so the category
/// picker is derived from this list rather than a second request.
class WorkflowAssetType {
  const WorkflowAssetType({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
  });

  final String id;
  final String name;
  final String categoryId;
  final String categoryName;

  // Compared by id so a dropdown's selection survives a list refetch.
  @override
  bool operator ==(Object other) =>
      other is WorkflowAssetType && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory WorkflowAssetType.fromJson(Map<String, dynamic> json) {
    return WorkflowAssetType(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      categoryId: json['asset_category_id']?.toString() ?? '',
      categoryName: json['category_name'] as String? ?? '',
    );
  }
}

/// A category grouping one or more [WorkflowAssetType]s.
typedef WorkflowAssetCategory = ({String id, String name});
