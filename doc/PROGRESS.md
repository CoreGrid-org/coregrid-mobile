# CoreGrid Mobile — Progress

Tracks what's actually built in **this repository** against the Flutter-tagged requirements in the main
[`CoreGrid` SRS](../../CoreGrid/doc/SRS/00-front-matter.md). Treat this file as more current than
assumptions about the codebase. For the platform-wide picture (backend + React status), see
[`CoreGrid/doc/PROGRESS.md`](../../CoreGrid/doc/PROGRESS.md); for how each requirement below maps to a
module, see [`MOBILE-SPECIFICATION.md` §8](MOBILE-SPECIFICATION.md#8-traceability); for who owns it, see
[`TEAM-ALLOCATION.md`](TEAM-ALLOCATION.md).

Status as of 2026-09-25: `features/auth/`, `features/dashboard/`, `features/verification/` and
`features/workflows/` (Student 4/Hasitha's full scope per `TEAM-ALLOCATION.md`) landed first: ThunderID PKCE
sign-in via `flutter_appauth`, the SRS §2.3.1/v1.5 role gate (Auditor/Administrator routed to
`/access-restricted`), sign-out revoking the refresh token against ThunderID's `oauth2/revoke` before
clearing local state (FR-008), and a role-branched dashboard — no dev/bypass sign-in path, every sign-in
goes through the real PKCE flow. `features/verification/` (task list, task-completion flow, manual
discrepancy raising with a compressed photo) and `features/workflows/` (initiate, poll status, show outcome)
are both live against the real backend — no mock data — and both Inventory-Officer-only, guarded at the
router level. Student 1 (Jayashan)'s `features/scan/` and the bulk of `features/assets/` have since landed
too: camera QR scan with torch/permission-refusal/unknown-code/offline handling, manual entry, attribute-
driven asset detail, condition update, and asset search all resolve against the real backend. One real gap
found while auditing this update, not yet fixed: FR-031's dedicated ad-hoc verification screen
(`AssetVerificationScreen`, `POST /api/assets/{id}/verify`) is built and has its own widget test, but is
**not wired into any route** — nothing in `lib/` navigates to it — so it's currently unreachable from the
running app; see FR-031's row below. `features/maintenance/`, `features/notifications/` and
`features/transfers/` are still empty — each owner builds their own per `CONTRIBUTING.md`.

## Legend

✅ Done &nbsp;·&nbsp; 🟡 Partial &nbsp;·&nbsp; ❌ Not started

## By requirement

| Requirement | Owner | Status |
|---|---|---|
| FR-001/007/008 — Sign in/out via ThunderID PKCE, role-aware nav, sign-out clears session | Student 4 (Hasitha) | ✅ (sign-in, role gate and route guard work; sign-out now revokes the stored refresh token via ThunderID's `oauth2/revoke` — RFC 7009 — before clearing local state, best-effort so an offline sign-out still succeeds locally) |
| FR-020 — Attribute-driven asset detail rendering | Student 1 (Jayashan) | ✅ (`features/assets/` — `AssetDetailScreen` renders custom attributes from `data_type` alone, no domain-specific code; see [`doc/features/asset-detail.md`](features/asset-detail.md). Widget-tested; reached routinely from both scan and manual lookup against the real backend, so the earlier "blocked on ThunderID native client" caveat on this row no longer holds — a dev ThunderID mobile client is configured (`.env.json`) and in active use) |
| FR-024 — QR scan → authoritative asset record within 3s | Student 1 (Jayashan) | ✅ (`features/scan/` opens the device camera from both dashboards, accepts QR codes, resolves `GET /api/assets/qr/{code}`, and immediately opens the returned authoritative record; torch, permission refusal, unknown-code, and offline recovery included. No widget test yet for `ScanAssetScreen` itself — worth adding before calling this fully evidenced per `TEAM-ALLOCATION.md`'s testing rule) |
| FR-025 — Manual asset-code entry fallback | Student 1 (Jayashan) | ✅ (`AssetLookupScreen` at `/assets`, reachable from both dashboards' "Enter Code" button and the scanner's camera-refused/error fallback → resolves via `GET /api/assets/qr/{code}` → detail screen; non-leaking 404 + offline states) |
| FR-028 — Asset search/filter (basic lookup + recent list) | Student 1 (Jayashan) | ✅ (dashboard Search Assets route with server-side search by code/name/custom attribute, department/location/category/asset-type/status/condition filters, sorting and pagination via `GET /api/assets`; mock asset data supported) |
| FR-029 — Record asset condition | Student 1 (Jayashan) | ✅ (`features/assets/` — `PATCH /api/assets/{id}/condition` via the condition-update sheet, five-point scale, history written server-side; gated client-side to ACTIVE/UNDER_MAINTENANCE. **Role gap found, not yet fixed:** the backend restricts this endpoint to `CanManageAssets` — InventoryOfficer/Administrator — but `AssetDetailActions` shows the "Update Condition" button to any signed-in role once the lifecycle check passes; there's a `canVerifyAssetsProvider` gating Verify but no equivalent for condition update, so a Staff user sees and can tap a button the backend will 403 — an IF-02 gap) |
| FR-031 — Physical verification (presence/location/condition assertion) | Student 1 (Jayashan) | ✅ (`AssetVerificationScreen` at `/assets/:id/verify` submits the ad-hoc assertion via `POST /api/assets/{id}/verify`; asset detail's Officer-only Verify action opens the pending campaign task when one exists, and falls through to the ad-hoc screen when none exists) |
| FR-033 — Fault report with photo evidence | Student 2 (Seneja) | ❌ |
| FR-037 — Maintenance status progress update | Student 2 (Seneja) | ❌ |
| FR-042 — Maintenance list/filter | Student 2 (Seneja) | ❌ |
| FR-043 — Raise transfer request | Student 3 (Bhanuka) | ❌ |
| FR-046 — Scan-to-confirm transfer receipt | Student 3 (Bhanuka) | ❌ |
| FR-058 — Verification task list, ordered by due date | Student 4 (Hasitha) | ✅ (`features/verification/` — `VerificationTaskListScreen` at `/verification`, `GET /api/verification-tasks?mine=true`, server-ordered by due date; loading/empty/error/populated states, overdue styling) |
| FR-059 — Complete verification task via scan | Student 4 (Hasitha) | ✅ (`VerificationTaskDetailScreen` at `/verification/:taskId` asserts presence/location/condition and submits via `PATCH /api/verification-tasks/{id}/complete`, which auto-raises a discrepancy per FR-060 server-side; reachable directly from the task list and from asset detail's Verify action when that asset has a pending task) |
| FR-061 — Raise discrepancy manually with photo | Student 4 (Hasitha) | ✅ (`RaiseDiscrepancyScreen` at `/verification/:taskId/discrepancy` — type/description/optional photo, compressed client-side to ≤1MB via `flutter_image_compress` (IF-11) before `POST /api/verification-tasks/photos` then `POST /api/verification-tasks/{taskId}/discrepancies`; backend role check widened to include InventoryOfficer — it was Auditor/Administrator-only, which would have 403'd every mobile call) |
| FR-067/069 — Initiate agentic evaluation, view workflow status | Student 4 (Hasitha) | ✅ (`features/workflows/` — `InitiateWorkflowScreen` at `/workflows/new` resolves an asset by code then `POST /api/agent-workflows`; `WorkflowListScreen`/`WorkflowDetailScreen` at `/workflows` and `/workflows/:id`, the latter polling `GET /api/agent-workflows/{id}` every 5s until resolved. This app never calls `/evaluate` or `/run-policy-agent` — those run inside the backend's own agent orchestration, not from a mobile trigger) |
| FR-076 — Display evaluation outcome | Student 4 (Hasitha) | ✅ (`WorkflowDetailScreen` — recommendation, approval status, high-impact flag, or the failure reason if the evaluation failed; no approval action, per the React-only responsibility boundary) |
| FR-080 — In-app notifications | Student 2 (Seneja) | ❌ |
| FR-083 — Task-focused dashboard | Student 4 (Hasitha) | 🟡 (role-branched per §2.3.1; "Verification Tasks Due" is now live via `features/verification/`, "Maintenance Assigned to Me"/"Transfers Awaiting My Confirmation" stay mock until `features/maintenance`/`features/transfers` exist to summarise — banner on-screen says so. Quick-action buttons were checked directly against `CoreGrid/doc/SRS/02-overall-description.md` §2.3.1's Mobile-users table, not `TEAM-ALLOCATION.md` — that file assigns folders to people, it doesn't define what a role may do. One gap found and fixed: Officer's dashboard had no Report Fault entry point even though FR-033 is Officer-*and*-Staff, not Staff-only; Staff's dashboard was already correctly scoped, and no dashboard exposes asset registration, which per §2.3.1 is React-only for every role, not just non-Flutter for Staff) |

## Next milestone

Student 4 (Hasitha)'s own scope — auth, dashboard, verification, workflows — is feature-complete against the
real backend. Student 1 (Jayashan)'s scan/asset work has also substantially landed; what's left there is
narrower than before: wire `AssetVerificationScreen` into a route (and an entry point on asset detail) so
FR-031's ad-hoc verification is actually reachable, and close the FR-029 role-gap above. What's still fully
outstanding is cross-owner: `features/maintenance/`/`features/notifications/` (Student 2), `features/transfers/`
(Student 3) so the dashboard's remaining two sections go live. The dev ThunderID mobile client
(`doc/setup/ThunderID-mobile-client.md`) is already registered and in local use (`.env.json`); what's still
outstanding on that front is the `staging`/`prod` client registrations `MOBILE-SPECIFICATION.md` §5.1 calls
for, needed before a release build rather than before local development.
