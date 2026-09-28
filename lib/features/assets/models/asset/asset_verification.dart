import 'asset_condition.dart';

class AssetVerificationRequest {
  const AssetVerificationRequest({
    required this.present,
    required this.locationId,
    required this.condition,
  });

  final bool present;
  final String locationId;
  final AssetCondition condition;

  Map<String, dynamic> toJson() => {
    'asserted_present': present,
    'asserted_location_id': locationId,
    'asserted_condition': condition.apiValue,
  };
}

class AssetVerificationResult {
  const AssetVerificationResult({
    required this.discrepancyRaised,
    this.message,
  });

  final bool discrepancyRaised;
  final String? message;

  factory AssetVerificationResult.fromJson(Map<String, dynamic> json) {
    return AssetVerificationResult(
      discrepancyRaised:
          (json['raised_discrepancy_types'] as List<dynamic>?)?.isNotEmpty ??
          json['discrepancy_raised'] as bool? ??
          json['has_discrepancy'] as bool? ??
          false,
      message: json['message'] as String? ?? json['detail'] as String?,
    );
  }
}
