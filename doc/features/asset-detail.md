# `features/assets/` — Asset Detail

Owner: **Student 1 — Jayashan Guruge** ([`TEAM-ALLOCATION.md`](../TEAM-ALLOCATION.md)).
Implements the Flutter slice of **Component A — Asset Registry & QR Identification**.

| Requirement | What this feature does |
|---|---|
| **FR-020** | Renders the asset detail read view **dynamically from the asset type's attribute definitions** — no hardcoded domain knowledge, same rule as the React client. |
| **FR-029** | Records an asset's condition on the defined scale (New / Good / Fair / Poor / Unserviceable); the change is written to asset history server-side. |
| **FR-028** (basic) | Lookup-by-code resolution only. Advanced search / filter / export stays React-only ([SRS §3.4](../../../CoreGrid/doc/SRS/03-system-architecture.md)). |
| **FR-024 AC4** | Department Staff never see the **Verify** action; the API rejects a direct verify call from Staff with 403 regardless. |
| **FR-024 A3/A4** | A code from another organisation shows "Asset not found" (never leaks existence); an offline device shows an offline state, never stale cached data. |

Spec reference: [`MOBILE-SPECIFICATION.md` §4.4](../MOBILE-SPECIFICATION.md).

## Routes

```
/assets       →   AssetLookupScreen           manual asset-code entry (FR-025)
/assets/:id   →   AssetDetailScreen(assetId)   the attribute-driven detail view (FR-020)
```

Both registered in `lib/app/router.dart`. `AssetLookupScreen` is reachable now from the **"Enter Code"**
button on both the Officer and Staff dashboards; it resolves the typed code via
`GET /api/assets/qr/{code}` and pushes `/assets/:id`. Once `features/scan/` lands, the camera scanner
becomes the other way in and the camera-refused fallback (IF-10) routes here.

## Backend API (client-only repo — all calls go to `../CoreGrid/backend/`)

| Call | Endpoint | Notes |
|---|---|---|
| Load asset | `GET /api/assets/{id}` | `AssetDetailDto`, JSON **snake_case** (`backend/Program.cs`). Cross-org id → 404. |
| Resolve by code | `GET /api/assets/qr/{code}` | Same body shape as by-id (AC3). Used by `features/scan/`; `AssetsApi.getByCode` lives here so the scan feature calls into it. |
| Record condition | `PATCH /api/assets/{id}/condition` | Body `{ "condition": "GOOD" }` (upper-case). Returns 204. Writes a `FIELD_AMENDMENT` history row. |
| History | `GET /api/assets/{id}/history?page=&page_size=` | `AssetHistoryDto[]` in `items`, newest first. Lazy-loaded when the History section is expanded. |

Condition values accepted by the API: `NEW`, `GOOD`, `FAIR`, `POOR`, `UNSERVICEABLE`
(`backend/Domain/Transfers/AssetStatusConstants.cs`).

## File layout

```
lib/features/assets/
  assets_api.dart              AssetsApi + assetsApiProvider — every /api/assets call this feature owns
  assets_providers.dart        assetDetailProvider (family), assetHistoryProvider (family),
                               canVerifyAssetsProvider, ConditionUpdateController
  models/
    asset_detail.dart          AssetDetail + AssetLifecycleStatus
    asset_attribute.dart       AssetAttribute + AssetAttributeType (TEXT|NUMBER|DATE|BOOLEAN, SELECT→text)
    asset_condition.dart       AssetCondition — the five-point scale, API value ⇄ label
    asset_history_entry.dart   AssetHistoryEntry
  screens/
    asset_lookup_screen.dart   manual code entry (FR-025) — the reachable entry point until features/scan/
    asset_detail_screen.dart   loading / error (not-found · offline · session-expired · generic) / populated
  widgets/
    asset_attribute_list.dart  FR-020 renderer — switches on data *type*, never attribute *name*
    asset_detail_actions.dart  Verify · Report Fault · Update Condition entry points (role/lifecycle-aware)
    condition_update_sheet.dart  FR-029 bottom sheet

lib/shared/api/
  api_client.dart              shared dio instance + bearer-token interceptor
  api_exception.dart           typed error model (field errors, network flag, 401/403/404 helpers)
```

> `lib/shared/api/` is nominally the app-shell owner's cross-cutting area
> ([`TEAM-ALLOCATION.md`](../TEAM-ALLOCATION.md)). A minimal client was stood up here to unblock this
> feature. **Not yet implemented** (left for the shell owner): the single silent refresh-and-retry on 401
> described in `MOBILE-SPECIFICATION.md` §3.4 — a 401 currently surfaces as a "session expired" error state.

## Behaviour notes

- **FR-020 realisation.** `AssetAttributeList` renders each attribute purely from its `data_type`. There is
  no `switch` on attribute name anywhere. Adding an asset type with new attributes on the backend needs zero
  changes here. `SELECT` collapses to text (a read view just shows the chosen option). An unrecognised
  future data type falls back to showing whatever scalar came back, rather than dropping it.
- **Condition-update gating.** The action is shown only while the asset is `ACTIVE` or `UNDER_MAINTENANCE`
  (`AssetDetail.allowsConditionUpdate`). This is client-side immediacy (IF-03) — the API remains the
  authority (C-07). On success the sheet invalidates `assetDetailProvider` / `assetHistoryProvider` so the
  screen re-reads the authoritative values instead of trusting a local guess.
- **Verify** is implemented as the Officer-only physical verification form in
  `features/assets/screens/asset_verification_screen.dart`; it submits presence,
  observed location, and condition to `POST /api/assets/{id}/verify` and shows
  success, discrepancy, and error states. Report Fault remains a "not built yet"
  entry point owned by `features/maintenance/` (Student 2).
- **`autoDispose`** on the detail/history providers — leaving the screen drops the cache so a re-scan always
  does a fresh read (FR-024 A4: never show stale business data as current).

## Tests

- `test/features/assets/asset_condition_test.dart` — scale exactness, `tryParse` behaviour.
- `test/features/assets/asset_detail_screen_test.dart` — attribute-driven rendering (FR-020), Staff hides
  Verify (AC4), Officer shows it, condition-update gating by lifecycle state, 404 → "Asset not found",
  network error → offline state.
- `test/features/assets/asset_lookup_screen_test.dart` — empty-input validation, non-leaking 404 message
  (AC2/A3), offline message (A4).

## Not done in this slice

- The camera scanner and permission/refused handling (`features/scan/`, FR-024, IF-10). Manual code entry
  (FR-025) has a minimal screen here; the full flow folds into `features/scan/`.
- The QR scanner and camera-permission handling (`features/scan/`, FR-024) remain
  separate from the completed verification form.
- Any list/search screen — out of scope per FR-028 note above.
- End-to-end run against a live backend is blocked locally until a native ThunderID client is registered
  (see the `running-the-app` session note); the feature is built to spec and covered by widget tests
  against a faked `AssetsApi`.
