import 'asset_attribute.dart';
import 'asset_condition.dart';

/// The authoritative asset record shown on the detail screen — the body of
/// `GET /api/assets/{id}` and `GET /api/assets/qr/{code}` (`AssetDetailDto`,
/// serialised snake_case per `backend/Program.cs`).
class AssetDetail {
  const AssetDetail({
    required this.id,
    required this.assetCode,
    required this.name,
    required this.assetTypeName,
    required this.departmentName,
    required this.locationName,
    required this.status,
    required this.conditionRaw,
    required this.acquisitionDate,
    required this.acquisitionCost,
    required this.residualValue,
    required this.qrPayload,
    required this.attributes,
  });

  final String id;
  final String assetCode;
  final String name;
  final String assetTypeName;
  final String departmentName;
  final String locationName;

  /// Raw lifecycle status string — see [AssetLifecycleStatus].
  final String status;

  /// Raw condition string from the API. Use [condition] for the parsed value.
  final String conditionRaw;

  final DateTime acquisitionDate;
  final num acquisitionCost;
  final num residualValue;
  final String qrPayload;
  final List<AssetAttribute> attributes;

  AssetLifecycleStatus get lifecycleStatus =>
      AssetLifecycleStatus.fromApi(status);

  AssetCondition? get condition => AssetCondition.tryParse(conditionRaw);

  /// Client-side gate for the Condition-update entry point (IF-03 — immediate
  /// feedback; the API remains the authority, C-07). Recording a fresh
  /// condition only makes sense while the asset is in the active register or
  /// being worked on; once it's in transit or has left the register, condition
  /// changes flow through those workflows instead.
  bool get allowsConditionUpdate => switch (lifecycleStatus) {
    AssetLifecycleStatus.active || AssetLifecycleStatus.underMaintenance => true,
    _ => false,
  };

  factory AssetDetail.fromJson(Map<String, dynamic> json) {
    final rawAttributes = json['attributes'];
    return AssetDetail(
      id: json['id']?.toString() ?? '',
      assetCode: json['asset_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      assetTypeName: json['asset_type_name'] as String? ?? '',
      departmentName: json['department_name'] as String? ?? '',
      locationName: json['location_name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      conditionRaw: json['condition'] as String? ?? '',
      acquisitionDate:
          DateTime.tryParse(json['acquisition_date'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      acquisitionCost: json['acquisition_cost'] as num? ?? 0,
      residualValue: json['residual_value'] as num? ?? 0,
      qrPayload: json['qr_payload'] as String? ?? '',
      attributes: rawAttributes is List
          ? rawAttributes
                .whereType<Map<String, dynamic>>()
                .map(AssetAttribute.fromJson)
                .toList()
          : const [],
    );
  }
}

/// Asset lifecycle states (`CK_Assets_Status`,
/// `backend/Domain/Transfers/AssetStatusConstants.cs`). [unknown] keeps the
/// client forward-compatible if the backend adds a state.
enum AssetLifecycleStatus {
  active('ACTIVE', 'Active'),
  underMaintenance('UNDER_MAINTENANCE', 'Under maintenance'),
  transferRequested('TRANSFER_REQUESTED', 'Transfer requested'),
  inTransit('IN_TRANSIT', 'In transit'),
  condemned('CONDEMNED', 'Condemned'),
  disposalRequested('DISPOSAL_REQUESTED', 'Disposal requested'),
  disposed('DISPOSED', 'Disposed'),
  unknown('', 'Unknown');

  const AssetLifecycleStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static AssetLifecycleStatus fromApi(String raw) {
    final normalized = raw.trim().toUpperCase();
    for (final s in AssetLifecycleStatus.values) {
      if (s.apiValue == normalized && s != unknown) return s;
    }
    return unknown;
  }
}
