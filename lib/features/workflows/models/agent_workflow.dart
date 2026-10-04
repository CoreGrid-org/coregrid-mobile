/// Matches `AgentWorkflowDto`. Holds workflow status, recommendation and approval state.
class AgentWorkflow {
  const AgentWorkflow({
    required this.id,
    required this.scope,
    this.assetId,
    required this.assetCode,
    required this.assetTypeName,
    required this.categoryName,
    required this.objective,
    required this.status,
    this.recommendation,
    required this.isHighImpact,
    required this.approvalStatus,
    required this.revisionCount,
    this.failureReason,
    this.fleet,
    required this.correlationId,
    this.initiatedByEmail,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
  });

  static const _inProgressStatuses = {'PLANNING', 'ANALYZING', 'VALIDATING'};
  static const _stoppedStatuses = {'FAILED_SAFE', 'REJECTED'};

  final String id;

  /// `ASSET` (one asset) or `ASSET_TYPE` (every active asset of a type).
  final String scope;
  final String? assetId;
  final String assetCode;
  final String assetTypeName;
  final String categoryName;
  final String objective;

  /// `PLANNING`, `ANALYZING`, `VALIDATING`, `AWAITING_APPROVAL`, `APPROVED`,
  /// `REJECTED`, `COMPLETED_ADVISORY`, `REVISION_REQUESTED` or `FAILED_SAFE`.
  final String status;
  final String? recommendation;
  final bool isHighImpact;

  /// `NOT_REQUIRED` | `PENDING` | `APPROVED` | `REJECTED`.
  final String approvalStatus;
  final int revisionCount;
  final String? failureReason;
  final FleetEvaluation? fleet;
  final String correlationId;
  final String? initiatedByEmail;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  bool get isSingleAsset => scope == 'ASSET' && assetId != null;
  bool get isInProgress => _inProgressStatuses.contains(status);
  bool get isAwaitingApproval => status == 'AWAITING_APPROVAL';
  bool get isFinished => !isInProgress && !isAwaitingApproval;
  bool get isStopped => _stoppedStatuses.contains(status);
  bool get needsRevision => status == 'REVISION_REQUESTED';

  /// The asset code for a single-asset evaluation, otherwise the asset type.
  String get targetLabel => isSingleAsset ? assetCode : '$assetTypeName fleet';

  /// Why the recommendation was made, for a single-asset evaluation.
  String? get reason =>
      isSingleAsset ? fleet?.assets.firstOrNull?.reason : null;

  factory AgentWorkflow.fromJson(Map<String, dynamic> json) {
    final fleet = json['fleet'];
    return AgentWorkflow(
      id: json['id'] as String,
      scope: json['scope'] as String? ?? 'ASSET',
      assetId: json['asset_id'] as String?,
      assetCode: json['asset_code'] as String? ?? '',
      assetTypeName: json['asset_type_name'] as String? ?? '',
      categoryName: json['category_name'] as String? ?? '',
      objective: json['objective'] as String? ?? '',
      status: (json['status'] as String? ?? '').toUpperCase(),
      recommendation: json['recommendation'] as String?,
      isHighImpact: json['is_high_impact'] as bool? ?? false,
      approvalStatus: json['approval_status'] as String? ?? '',
      revisionCount: (json['revision_count'] as num?)?.toInt() ?? 0,
      failureReason: json['failure_reason'] as String?,
      fleet: fleet is Map<String, dynamic>
          ? FleetEvaluation.fromJson(fleet)
          : null,
      correlationId: json['correlation_id'] as String? ?? '',
      initiatedByEmail: json['initiated_by_email'] as String?,
      startedAt: _parseDate(json['started_at']),
      completedAt: _parseDate(json['completed_at']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}

/// The Policy Compliance result across the evaluated assets.
class FleetEvaluation {
  const FleetEvaluation({
    required this.assetCount,
    required this.actionCounts,
    required this.passCount,
    required this.deferredCount,
    required this.blockedCount,
    required this.assets,
  });

  final int assetCount;
  final Map<String, int> actionCounts;
  final int passCount;
  final int deferredCount;
  final int blockedCount;
  final List<FleetAssetResult> assets;

  factory FleetEvaluation.fromJson(Map<String, dynamic> json) {
    final counts = json['action_counts'];
    final assets = json['assets'];
    return FleetEvaluation(
      assetCount: (json['asset_count'] as num?)?.toInt() ?? 0,
      actionCounts: counts is Map
          ? counts.map((k, v) => MapEntry(k as String, (v as num).toInt()))
          : const {},
      passCount: (json['pass_count'] as num?)?.toInt() ?? 0,
      deferredCount: (json['deferred_count'] as num?)?.toInt() ?? 0,
      blockedCount: (json['blocked_count'] as num?)?.toInt() ?? 0,
      assets: assets is List
          ? assets
                .whereType<Map<String, dynamic>>()
                .map(FleetAssetResult.fromJson)
                .toList()
          : const [],
    );
  }
}

/// One asset's chosen action and the reason for it.
class FleetAssetResult {
  const FleetAssetResult({
    required this.assetCode,
    required this.action,
    required this.verdict,
    required this.reason,
  });

  final String assetCode;
  final String action;
  final String verdict;
  final String reason;

  factory FleetAssetResult.fromJson(Map<String, dynamic> json) {
    return FleetAssetResult(
      assetCode: json['asset_code'] as String? ?? '',
      action: json['action'] as String? ?? '',
      verdict: json['verdict'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
    );
  }
}
