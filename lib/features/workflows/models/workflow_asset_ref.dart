/// Minimal asset reference needed to initiate a workflow. The asset type
/// lets the officer widen a single-asset evaluation to the whole type.
class WorkflowAssetRef {
  const WorkflowAssetRef({
    required this.id,
    required this.assetCode,
    required this.name,
    this.assetTypeId = '',
    this.assetTypeName = '',
  });

  final String id;
  final String assetCode;
  final String name;
  final String assetTypeId;
  final String assetTypeName;

  factory WorkflowAssetRef.fromJson(Map<String, dynamic> json) {
    return WorkflowAssetRef(
      id: json['id'] as String,
      assetCode: json['asset_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      assetTypeId: json['asset_type_id']?.toString() ?? '',
      assetTypeName: json['asset_type_name'] as String? ?? '',
    );
  }
}
