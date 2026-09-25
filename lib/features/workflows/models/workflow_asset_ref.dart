/// Minimal asset reference needed to initiate a workflow.
class WorkflowAssetRef {
  const WorkflowAssetRef({
    required this.id,
    required this.assetCode,
    required this.name,
  });

  final String id;
  final String assetCode;
  final String name;

  factory WorkflowAssetRef.fromJson(Map<String, dynamic> json) {
    return WorkflowAssetRef(
      id: json['id'] as String,
      assetCode: json['asset_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}
