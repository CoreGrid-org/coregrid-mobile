# CoreGrid Mobile — Progress

Tracks what's actually built in **this repository** against the Flutter-tagged requirements in the main
[`CoreGrid` SRS](../../CoreGrid/doc/SRS/00-front-matter.md). Treat this file as more current than
assumptions about the codebase. For the platform-wide picture (backend + React status), see
[`CoreGrid/doc/PROGRESS.md`](../../CoreGrid/doc/PROGRESS.md); for how each requirement below maps to a
module, see [`MOBILE-SPECIFICATION.md` §8](MOBILE-SPECIFICATION.md#8-traceability); for who owns it, see
[`TEAM-ALLOCATION.md`](TEAM-ALLOCATION.md).

Status as of 2026-09-15: - 'Hasitha Erandika' `flutter create` run, project skeleton in place (`lib/app/`, `lib/shared/theme/`,
mandated + supporting packages from `MOBILE-SPECIFICATION.md` §2 added to `pubspec.yaml`), CI wired up
(`.github/workflows/ci.yml`), `flutter analyze`/`flutter test` passing, and a debug APK builds successfully.
`features/auth/`, `features/dashboard/`, `features/verification/` and `features/workflows/` have all landed
(this owner's full scope per `TEAM-ALLOCATION.md`): ThunderID PKCE sign-in via `flutter_appauth`, the SRS
§2.3.1/v1.5 role gate (Auditor/Administrator routed to `/access-restricted`), sign-out now revokes the
refresh token against ThunderID's `oauth2/revoke` before clearing local state (FR-008), a `kDebugMode`-only
Dev Sign In bypass, and a role-branched dashboard. `features/verification/` (task list, scan-stand-in
complete flow, manual discrepancy raising with a compressed photo) and `features/workflows/` (initiate,
poll status, show outcome) are both live against the real backend — no mock data — and both are
Inventory-Officer-only, guarded at the router level (`go_router`'s `redirect`), matching the SRS's
"Flutter is field operations, Officer + Staff only" split (v1.5). The dashboard's "Verification Tasks Due"
section now reads live data from `features/verification/`; "Maintenance Assigned to Me" and "Transfers
Awaiting My Confirmation" stay mock until their owners' features exist to summarise. `features/assets/`
(Student 1) is also underway; `features/scan/`, `features/maintenance/`, `features/notifications/` and
`features/transfers/` are still empty — each owner builds their own per `CONTRIBUTING.md`.

## Legend

✅ Done &nbsp;·&nbsp; 🟡 Partial &nbsp;·&nbsp; ❌ Not started

## By requirement

| Requirement | Owner | Status |
|---|---|---|
| FR-001/007/008 — Sign in/out via ThunderID PKCE, role-aware nav, sign-out clears session | Student 4 (Hasitha) | ✅ (sign-in, role gate and route guard work; sign-out now revokes the stored refresh token via ThunderID's `oauth2/revoke` — RFC 7009 — before clearing local state, best-effort so an offline sign-out still succeeds locally) |
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
| FR-058 — Verification task list, ordered by due date | Student 4 (Hasitha) | ✅ (`features/verification/` — `VerificationTaskListScreen` at `/verification`, `GET /api/verification-tasks?mine=true`, server-ordered by due date; loading/empty/error/populated states, overdue styling) |
| FR-059 — Complete verification task via scan | Student 4 (Hasitha) | 🟡 (`VerificationTaskDetailScreen` at `/verification/:taskId` asserts presence/location/condition and submits via `PATCH /api/verification-tasks/{id}/complete`, which auto-raises a discrepancy per FR-060 server-side; reached directly from the task list rather than a scan, since `features/scan/` — Student 1 — isn't built yet, same stand-in `features/assets/` already uses for manual entry) |
| FR-061 — Raise discrepancy manually with photo | Student 4 (Hasitha) | ✅ (`RaiseDiscrepancyScreen` at `/verification/:taskId/discrepancy` — type/description/optional photo, compressed client-side to ≤1MB via `flutter_image_compress` (IF-11) before `POST /api/verification-tasks/photos` then `POST /api/verification-tasks/{taskId}/discrepancies`; backend role check widened to include InventoryOfficer — it was Auditor/Administrator-only, which would have 403'd every mobile call) |
| FR-067/069 — Initiate agentic evaluation, view workflow status | Student 4 (Hasitha) | ✅ (`features/workflows/` — `InitiateWorkflowScreen` at `/workflows/new` resolves an asset by code then `POST /api/agent-workflows`; `WorkflowListScreen`/`WorkflowDetailScreen` at `/workflows` and `/workflows/:id`, the latter polling `GET /api/agent-workflows/{id}` every 5s until resolved. This app never calls `/evaluate` or `/run-policy-agent` — those run inside the backend's own agent orchestration, not from a mobile trigger) |
| FR-076 — Display evaluation outcome | Student 4 (Hasitha) | ✅ (`WorkflowDetailScreen` — recommendation, approval status, high-impact flag, or the failure reason if the evaluation failed; no approval action, per the React-only responsibility boundary) |
| FR-080 — In-app notifications | Student 2 (Seneja) | ❌ |
| FR-083 — Task-focused dashboard | Student 4 (Hasitha) | 🟡 (role-branched per §2.3.1; "Verification Tasks Due" is now live via `features/verification/`, "Maintenance Assigned to Me"/"Transfers Awaiting My Confirmation" stay mock until `features/maintenance`/`features/transfers` exist to summarise — banner on-screen says so) |

## Next milestone

Student 4 (Hasitha)'s own scope — auth, dashboard, verification, workflows — is now feature-complete
against the real backend. What's outstanding is cross-owner: `features/scan/` (Student 1) so FR-059/FR-031
stop standing in with manual entry; `features/maintenance/`/`features/transfers/` (Students 2/3) so the
dashboard's remaining two sections go live; and the one-time ThunderID console step (registering this app
as a mobile/native PKCE client per `doc/setup/ThunderID-mobile-client.md`) needed before any of this can be
exercised against a real sign-in end-to-end.
