/// The minimal asset reference needed to initiate a workflow (FR-067) —
/// resolved from a manually-typed code via `GET /api/assets/qr/{code}`
/// (the same endpoint `features/assets/` uses, called independently here
/// rather than importing that feature's API client — §3.1: a feature owns
/// its own API calls). Kept to just the fields this screen displays.
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
