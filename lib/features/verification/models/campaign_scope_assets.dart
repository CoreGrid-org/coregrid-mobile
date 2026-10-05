import '../../assets/models/asset/asset_detail.dart';

/// The registered assets that fall inside a campaign's scope, read from
/// `GET /api/assets` with the campaign's own scope filters. Gives the
/// officer each task's asset type and registered location (what to look
/// for, and where), and lets a campaign scan tell "belongs here but isn't
/// yours" apart from "not part of this campaign at all".
///
/// [complete] is false when the scope is larger than the client is willing
/// to page through — callers then fall back to a by-name scope check.
class CampaignScopeAssets {
  CampaignScopeAssets({required List<AssetDetail> assets, this.complete = true})
    : _byId = {for (final a in assets) a.id: a};

  final Map<String, AssetDetail> _byId;
  final bool complete;

  AssetDetail? operator [](String assetId) => _byId[assetId];

  bool contains(String assetId) => _byId.containsKey(assetId);
}
