/// One custom-attribute value on an asset, as returned inside
/// `GET /api/assets/{id}` → `attributes[]` (`AssetAttributeValueDto`).
///
/// FR-020: the client renders these with **no domain-specific knowledge** —
/// it only knows the generic [dataType]s the platform supports, never what any
/// particular attribute means. Adding an asset type with new attributes is a
/// config change on the backend, never a change here.
class AssetAttribute {
  const AssetAttribute({
    required this.definitionId,
    required this.name,
    required this.dataType,
    required this.isRequired,
    this.valueText,
    this.valueNumber,
    this.valueDate,
    this.valueBoolean,
  });

  final String definitionId;
  final String name;

  /// `TEXT | NUMBER | DATE | BOOLEAN | SELECT`
  /// (`backend/Domain/Assets/AssetAttributeDefinition.cs`). Kept as the raw
  /// string — [AssetAttributeType.fromApi] maps it for rendering.
  final String dataType;
  final bool isRequired;

  final String? valueText;
  final num? valueNumber;
  final DateTime? valueDate;
  final bool? valueBoolean;

  AssetAttributeType get type => AssetAttributeType.fromApi(dataType);

  /// True when the asset has no value stored for this attribute.
  bool get isEmpty =>
      valueText == null &&
      valueNumber == null &&
      valueDate == null &&
      valueBoolean == null;

  factory AssetAttribute.fromJson(Map<String, dynamic> json) {
    final rawDate = json['value_date'] as String?;
    return AssetAttribute(
      definitionId: json['attribute_definition_id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      dataType: json['data_type'] as String? ?? '',
      isRequired: json['is_required'] as bool? ?? false,
      valueText: json['value_text'] as String?,
      valueNumber: json['value_number'] as num?,
      valueDate: rawDate == null ? null : DateTime.tryParse(rawDate),
      valueBoolean: json['value_boolean'] as bool?,
    );
  }
}

/// The rendering-relevant shape of an attribute. `SELECT` collapses to [text]
/// deliberately — a read view shows the chosen option as-is and needs nothing
/// domain-specific to do so.
enum AssetAttributeType {
  text,
  number,
  date,
  boolean,
  unknown;

  static AssetAttributeType fromApi(String dataType) {
    switch (dataType.trim().toUpperCase()) {
      case 'TEXT':
      case 'SELECT':
        return AssetAttributeType.text;
      case 'NUMBER':
        return AssetAttributeType.number;
      case 'DATE':
        return AssetAttributeType.date;
      case 'BOOLEAN':
        return AssetAttributeType.boolean;
      default:
        return AssetAttributeType.unknown;
    }
  }
}
