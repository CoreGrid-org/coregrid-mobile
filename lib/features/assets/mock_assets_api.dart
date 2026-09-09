import 'assets_api.dart';
import 'models/asset/asset_condition.dart';
import 'models/asset/asset_detail.dart';
import 'models/asset/asset_history_entry.dart';
import 'models/asset/asset_search.dart';
import 'models/asset/asset_verification.dart';

/// In-memory API for emulator checks of the asset feature without CoreGrid or
/// ThunderID. It implements the same [AssetsApi] contract used by providers.
class MockAssetsApi implements AssetsApi, SearchableAssetsApi, VerifiableAssetsApi {
  AssetCondition _condition = AssetCondition.good;
  final List<AssetHistoryEntry> _history = [
    AssetHistoryEntry(
      id: 'history-1',
      eventType: 'FIELD_AMENDMENT',
      description: 'Condition changed to Good',
      createdAt: DateTime.utc(2024, 7, 1, 9),
    ),
    AssetHistoryEntry(
      id: 'history-2',
      eventType: 'FIELD_AMENDMENT',
      description: 'Condition changed to Good',
      createdAt: DateTime.utc(2024, 8, 15, 12, 30),
    ),
  ];

  @override
  Future<AssetDetail> getById(String assetId) async => _asset;

  @override
  Future<AssetDetail> getByCode(String assetCode) async => _asset;

  @override
  Future<AssetSearchResult> search(AssetSearchQuery query) async {
    final normalizedSearch = query.search.trim().toLowerCase();
    final matches = [
      _asset,
    ].where((asset) {
      final searchable = [
        asset.id,
        asset.assetCode,
        asset.name,
        asset.assetTypeName,
        asset.departmentName,
        asset.locationName,
        asset.conditionRaw,
        ...asset.attributes.map(
          (attribute) =>
              '${attribute.name} ${attribute.valueText ?? attribute.valueNumber ?? attribute.valueDate ?? attribute.valueBoolean ?? ''}',
        ),
      ].join(' ').toLowerCase();
      return (normalizedSearch.isEmpty || searchable.contains(normalizedSearch)) &&
          (query.department.isEmpty ||
              asset.departmentName.toLowerCase().contains(
                query.department.toLowerCase(),
              )) &&
          (query.location.isEmpty ||
              asset.locationName.toLowerCase().contains(
                query.location.toLowerCase(),
              )) &&
          (query.category.isEmpty ||
              'equipment'.contains(query.category.toLowerCase())) &&
          (query.assetType.isEmpty ||
              asset.assetTypeName.toLowerCase().contains(
                query.assetType.toLowerCase(),
              )) &&
          (query.status.isEmpty ||
              asset.status.toLowerCase() == query.status.toLowerCase()) &&
          (query.condition.isEmpty ||
              asset.conditionRaw.toLowerCase() == query.condition.toLowerCase());
    }).toList();
    return AssetSearchResult(
      items: matches,
      page: 1,
      pageSize: query.pageSize,
      totalCount: matches.length,
    );
  }

  @override
  Future<void> updateCondition({
    required String assetId,
    required AssetCondition condition,
  }) async {
    _condition = condition;
    _history.insert(
      0,
      AssetHistoryEntry(
        id: 'history-${_history.length + 1}',
        eventType: 'FIELD_AMENDMENT',
        description: 'Condition changed to ${condition.label}',
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<AssetVerificationResult> verifyAsset({
    required String assetId,
    required AssetVerificationRequest request,
  }) async {
    final discrepancy =
        !request.present ||
        request.location.trim().toLowerCase() !=
            _asset.locationName.toLowerCase() ||
        request.condition != _condition;
    return AssetVerificationResult(
      discrepancyRaised: discrepancy,
      message: discrepancy
          ? 'A verification discrepancy was raised.'
          : 'Asset verified successfully with no discrepancy.',
    );
  }

  @override
  Future<List<AssetHistoryEntry>> getHistory(
    String assetId, {
    int page = 1,
    int pageSize = 50,
  }) async => List.unmodifiable(_history);

  AssetDetail get _asset => AssetDetail.fromJson({
    'id': 'asset-12345',
    'asset_code': 'asset-12345',
    'name': 'Hydraulic Pump',
    'asset_type_name': 'Equipment',
    'department_name': 'Operations',
    'location_name': 'Plant A - Section 3',
    'status': 'ACTIVE',
    'condition': _condition.apiValue,
    'acquisition_date': '2022-05-10',
    'acquisition_cost': 0,
    'residual_value': 0,
    'qr_payload': 'asset-12345',
    'attributes': [
      {
        'attribute_definition_id': 'manufacturer',
        'name': 'Manufacturer',
        'data_type': 'TEXT',
        'is_required': true,
        'value_text': 'Acme Corp',
      },
      {
        'attribute_definition_id': 'model',
        'name': 'Model',
        'data_type': 'TEXT',
        'is_required': true,
        'value_text': 'X200',
      },
      {
        'attribute_definition_id': 'capacity',
        'name': 'Capacity',
        'data_type': 'TEXT',
        'is_required': true,
        'value_text': '2000 L/min',
      },
      {
        'attribute_definition_id': 'serial-number',
        'name': 'Serial Number',
        'data_type': 'TEXT',
        'is_required': true,
        'value_text': 'SN-00112233',
      },
      {
        'attribute_definition_id': 'installation-date',
        'name': 'Installation Date',
        'data_type': 'DATE',
        'is_required': true,
        'value_date': '2022-05-10',
      },
      {
        'attribute_definition_id': 'location',
        'name': 'Location',
        'data_type': 'TEXT',
        'is_required': true,
        'value_text': 'Plant A - Section 3',
      },
    ],
  });
}