import 'asset_condition.dart';

class AssetVerificationRequest {
  const AssetVerificationRequest({
    required this.present,
    required this.location,
    required this.condition,
  });

  final bool present;
  final String location;
  final AssetCondition condition;

  Map<String, dynamic> toJson() => {
    'is_present': present,
    'location': location.trim(),
    'condition': condition.apiValue,
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
          json['discrepancy_raised'] as bool? ??
          json['has_discrepancy'] as bool? ??
          false,
      message: json['message'] as String? ?? json['detail'] as String?,
    );
  }
}
