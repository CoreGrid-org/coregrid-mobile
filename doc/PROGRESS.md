# CoreGrid Mobile — Progress

Tracks what's actually built in **this repository** against the Flutter-tagged requirements in the main
[`CoreGrid` SRS](../../CoreGrid/doc/SRS/00-front-matter.md). Treat this file as more current than
assumptions about the codebase. For the platform-wide picture (backend + React status), see
[`CoreGrid/doc/PROGRESS.md`](../../CoreGrid/doc/PROGRESS.md); for how each requirement below maps to a
module, see [`MOBILE-SPECIFICATION.md` §8](MOBILE-SPECIFICATION.md#8-traceability); for who owns it, see
[`TEAM-ALLOCATION.md`](TEAM-ALLOCATION.md).

Status as of 2026-08-18: - 'Hasitha Erandika' `flutter create` run, project skeleton in place (`lib/app/`, `lib/shared/theme/`,
mandated + supporting packages from `MOBILE-SPECIFICATION.md` §2 added to `pubspec.yaml`), CI wired up
(`.github/workflows/ci.yml`), `flutter analyze`/`flutter test` passing, and a debug APK builds successfully.
`features/auth/` and `features/dashboard/` have landed (both this owner's scope per `TEAM-ALLOCATION.md`):
ThunderID PKCE sign-in via `flutter_appauth`, the SRS §2.3.1/v1.5 role gate (Auditor/Administrator routed to
`/access-restricted`), a `kDebugMode`-only Dev Sign In bypass, and a role-branched dashboard — Officer and
Staff see different sections, matching §2.3.1 exactly, but every row is **mock/hardcoded data** (a banner
says so on-screen); no `/api/...` call exists yet. Every other `lib/features/` folder is still empty; each
owner creates their own per `CONTRIBUTING.md`.

## Legend

✅ Done &nbsp;·&nbsp; 🟡 Partial &nbsp;·&nbsp; ❌ Not started

## By requirement

| Requirement | Owner | Status |
|---|---|---|
| FR-001/007/008 — Sign in/out via ThunderID PKCE, role-aware nav, sign-out clears session | Student 4 (Hasitha) | 🟡 (sign-in, role gate and route guard work; sign-out clears local state only — doesn't yet call ThunderID's revoke/end-session endpoint, so FR-008's "terminate the identity-provider session" isn't fully met) |
| FR-020 — Attribute-driven asset detail rendering | Student 1 (Jayashan) | ✅ (`features/assets/` — `AssetDetailScreen` renders custom attributes from `data_type` alone, no domain-specific code; see [`doc/features/asset-detail.md`](features/asset-detail.md). Widget-tested; not yet exercised end-to-end against a live backend — blocked on ThunderID native client) |
| FR-024 — QR scan → authoritative asset record within 3s | Student 1 (Jayashan) | 🟡 (`GET /api/assets/{id}` + `qr/{code}` client, the manual-entry lookup screen and the detail screen it lands on are done; the camera scanner itself — `features/scan/` — is not) |
| FR-025 — Manual asset-code entry fallback | Student 1 (Jayashan) | 🟡 (`AssetLookupScreen` at `/assets`, reachable from both dashboards' "Enter Code" button → resolves via `GET /api/assets/qr/{code}` → detail screen; non-leaking 404 + offline states. The full camera-refused fallback wiring folds in with `features/scan/`) |
| FR-028 — Asset search/filter (basic lookup + recent list) | Student 1 (Jayashan) | ✅ (dashboard Search Assets route with server-side search by code/name/custom attribute, department/location/category/asset-type/status/condition filters, sorting and pagination via `GET /api/assets`; mock asset data supported) |
| FR-029 — Record asset condition | Student 1 (Jayashan) | ✅ (`features/assets/` — `PATCH /api/assets/{id}/condition` via the condition-update sheet, five-point scale, history written server-side; gated client-side to ACTIVE/UNDER_MAINTENANCE) |
| FR-031 — Physical verification (presence/location/condition assertion) | Student 1 (Jayashan) | ❌ |
| FR-033 — Fault report with photo evidence | Student 2 (Seneja) | ❌ |
| FR-037 — Maintenance status progress update | Student 2 (Seneja) | ❌ |
| FR-042 — Maintenance list/filter | Student 2 (Seneja) | ❌ |
| FR-043 — Raise transfer request | Student 3 (Bhanuka) | ❌ |
| FR-046 — Scan-to-confirm transfer receipt | Student 3 (Bhanuka) | ❌ |
| FR-058 — Verification task list, ordered by due date | Student 4 (Hasitha) | ❌ |
| FR-059 — Complete verification task via scan | Student 4 (Hasitha) | ❌ |
| FR-061 — Raise discrepancy manually with photo | Student 4 (Hasitha) | ❌ |
| FR-067/069 — Initiate agentic evaluation, view workflow status | Student 4 (Hasitha) | ❌ |
| FR-076 — Display evaluation outcome | Student 4 (Hasitha) | ❌ |
| FR-080 — In-app notifications | Student 2 (Seneja) | ❌ |
| FR-083 — Task-focused dashboard | Student 4 (Hasitha) | 🟡 (mock scaffold, role-branched per §2.3.1 — no live data/API call yet) |

## Next milestone

Vertical slice: `flutter create`, project skeleton per `CONTRIBUTING.md`, ThunderID PKCE sign-in against a
running CoreGrid backend, and one read-only screen (asset detail via manual code entry) to prove the
API-only communication path end-to-end before building the scanner.
