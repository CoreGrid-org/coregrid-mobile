/// Request body for `POST /api/transfers`
/// (`backend/Features/Transfers/DTOs/TransferDtos.cs`
/// `InitiateTransferRequest`). All three fields are [Required] on the
/// backend; the form validates them client-side before calling [toJson].
class InitiateTransferRequest {
  const InitiateTransferRequest({
    required this.assetId,
    required this.toDepartmentId,
    required this.toLocationId,
  });

  final String assetId;
  final String toDepartmentId;
  final String toLocationId;

  /// Produces the snake_case JSON body expected by the backend
  /// (`JsonNamingPolicy.SnakeCaseLower`).
  Map<String, dynamic> toJson() => {
        'asset_id': assetId,
        'to_department_id': toDepartmentId,
        'to_location_id': toLocationId,
      };
}
