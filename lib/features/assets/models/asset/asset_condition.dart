/// The five-point asset-condition scale (FR-029). API values are upper-case
/// (`backend/Domain/Transfers/AssetStatusConstants.cs`); the labels below match
/// the SRS wording exactly (main SRS §6.4).
enum AssetCondition {
  brandNew('NEW', 'New'),
  good('GOOD', 'Good'),
  fair('FAIR', 'Fair'),
  poor('POOR', 'Poor'),
  unserviceable('UNSERVICEABLE', 'Unserviceable');

  const AssetCondition(this.apiValue, this.label);

  /// The exact string the API expects / returns.
  final String apiValue;

  /// Display text, per the SRS's defined scale.
  final String label;

  /// Resolves an API string (case-insensitively) to a value, or null if the
  /// backend ever returns something outside the scale — the caller decides
  /// whether to show the raw string or treat it as unknown.
  static AssetCondition? tryParse(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().toUpperCase();
    for (final c in AssetCondition.values) {
      if (c.apiValue == normalized) return c;
    }
    return null;
  }
}
