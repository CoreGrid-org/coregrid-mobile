class AssetMaintenanceHistory {
  const AssetMaintenanceHistory({required this.assetId, required this.records});

  final String assetId;
  final List<AssetMaintenanceRecord> records;

  factory AssetMaintenanceHistory.fromJson(Map<String, dynamic> json) {
    final rawRecords = json['records'];
    return AssetMaintenanceHistory(
      assetId: json['asset_id']?.toString() ?? '',
      records: rawRecords is List
          ? rawRecords
                .whereType<Map<String, dynamic>>()
                .map(AssetMaintenanceRecord.fromJson)
                .toList()
          : const [],
    );
  }

  List<AssetMaintenanceRecord> get completedRecords => records
      .where((record) => record.status.toUpperCase() == 'COMPLETED')
      .toList();

  int get repairCount => completedRecords.length;

  DateTime? get lastRepairDate {
    final dates =
        completedRecords
            .map((record) => record.completionDate)
            .whereType<DateTime>()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return dates.firstOrNull;
  }

  num get totalRepairCost => completedRecords.fold<num>(
    0,
    (total, record) => total + (record.actualCost ?? 0),
  );
}

class AssetMaintenanceRecord {
  const AssetMaintenanceRecord({
    required this.id,
    required this.status,
    this.completionDate,
    this.actualCost,
  });

  final String id;
  final String status;
  final DateTime? completionDate;
  final num? actualCost;

  factory AssetMaintenanceRecord.fromJson(Map<String, dynamic> json) {
    return AssetMaintenanceRecord(
      id: json['id']?.toString() ?? '',
      status: json['status'] as String? ?? '',
      completionDate: _parseDate(json['completion_date']),
      actualCost: json['actual_cost'] as num?,
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
