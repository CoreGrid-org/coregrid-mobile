/// Matches `AgentWorkflowDto`. Holds workflow status, recommendation and approval state.
class AgentWorkflow {
  const AgentWorkflow({
    required this.id,
    required this.assetId,
    required this.assetCode,
    required this.objective,
    required this.status,
    this.recommendation,
    required this.isHighImpact,
    required this.approvalStatus,
    this.failureReason,
    required this.correlationId,
    this.initiatedByEmail,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
  });

  final String id;
  final String assetId;
  final String assetCode;
  final String objective;

  /// One of the SRS §7 workflow states (e.g. `PLANNING`, `AWAITING_APPROVAL`,
  /// `COMPLETED`, `FAILED`) — shown verbatim rather than re-enumerated here,
  /// since the backend is the source of truth for the state machine.
  final String status;
  final String? recommendation;
  final bool isHighImpact;

  /// `PENDING` | `APPROVED` | `REJECTED` | not applicable to every status.
  final String approvalStatus;
  final String? failureReason;
  final String correlationId;
  final String? initiatedByEmail;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  bool get isResolved => completedAt != null;
  bool get isFailed => status.toUpperCase() == 'FAILED';
  bool get awaitingApproval => approvalStatus.toUpperCase() == 'PENDING' && isHighImpact;

  factory AgentWorkflow.fromJson(Map<String, dynamic> json) {
    return AgentWorkflow(
      id: json['id'] as String,
      assetId: json['asset_id'] as String? ?? '',
      assetCode: json['asset_code'] as String? ?? '',
      objective: json['objective'] as String? ?? '',
      status: json['status'] as String? ?? '',
      recommendation: json['recommendation'] as String?,
      isHighImpact: json['is_high_impact'] as bool? ?? false,
      approvalStatus: json['approval_status'] as String? ?? '',
      failureReason: json['failure_reason'] as String?,
      correlationId: json['correlation_id'] as String? ?? '',
      initiatedByEmail: json['initiated_by_email'] as String?,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
