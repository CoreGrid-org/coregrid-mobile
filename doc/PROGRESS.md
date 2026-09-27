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

**2026-09-27 — app-wide redesign and navigation.** The app now runs in a role-filtered bottom-navigation
shell (Home · Verify · Workflows · Faults · Account for Officers; Home · Faults · Account for Staff — see
`MOBILE-SPECIFICATION.md` §3.3), with a new Account tab (`GET /api/me` profile, confirmed sign-out) and a
Faults tab listing the user's own fault reports. Every screen, including `features/scan/`,
`features/assets/` and `features/maintenance/`, was restyled onto one shared UI kit
(`shared/widgets/ui.dart`) and theme — no screen hard-codes its own palette any more. Behaviour, API
calls and on-screen strings the tests depend on were kept; the only deliberate test-visible changes are
sentence-case titles ("Fault report"), `d MMM y` dates, and relative due dates ("Overdue by 3 days").

**2026-09-27 — verification procedure, department context, refactor.** Staff take no part in verification
(FR-031/058/059/061 are Officer-only; SRS §3.4.1) — the procedure is Officer: scan the label → the matching
campaign task (or ad-hoc) → assert → submit. Account and Home now show the user's department and its
locations (`GET /api/me` `department_id` + `/api/departments`, `/api/locations?departmentId=`); Staff search
filters drop the Department filter and list only their department's locations. Data scoping itself stays
server-side (`DepartmentScope`: Staff → own department, others org-wide) — the app never filters API
results. Also: org-config filter lists now request `pageSize=100` (they silently stopped at 20); dead
`getOpenDiscrepancies` (Auditor/Admin-only endpoint, would 403 for an Officer) removed; photo compression
and several widgets de-duplicated into `shared/`; Faults polling pauses when the tab is hidden.

## Legend

✅ Done &nbsp;·&nbsp; 🟡 Partial &nbsp;·&nbsp; ❌ Not started

## By requirement

| Requirement | Owner | Status |
|---|---|---|
| FR-001/007/008 — Sign in/out via ThunderID PKCE, role-aware nav, sign-out clears session | Student 4 (Hasitha) | ✅ (sign-in, role gate and route guard work; sign-out now revokes the stored refresh token via ThunderID's `oauth2/revoke` — RFC 7009 — before clearing local state, best-effort so an offline sign-out still succeeds locally) |
| FR-020 — Attribute-driven asset detail rendering | Student 1 (Jayashan) | ✅ (`features/assets/` — `AssetDetailScreen` renders custom attributes from `data_type` alone, no domain-specific code; see [`doc/features/asset-detail.md`](features/asset-detail.md). Widget-tested; reached routinely from both scan and manual lookup against the real backend, so the earlier "blocked on ThunderID native client" caveat on this row no longer holds — a dev ThunderID mobile client is configured (`.env.json`) and in active use) |
| FR-024 — QR scan → authoritative asset record within 3s | Student 1 (Jayashan) | ✅ (`features/scan/` opens the device camera from both dashboards, accepts QR codes, resolves `GET /api/assets/qr/{code}`, and immediately opens the returned authoritative record; torch, permission refusal, unknown-code, and offline recovery included. No widget test yet for `ScanAssetScreen` itself — worth adding before calling this fully evidenced per `TEAM-ALLOCATION.md`'s testing rule) |
| FR-025 — Manual asset-code entry fallback | Student 1 (Jayashan) | ✅ (`AssetLookupScreen` at `/assets`, reachable from the scanner's "Enter code instead" and camera-refused/error fallback; the dashboard's "Find an asset" field also resolves a typed code via the same call → resolves via `GET /api/assets/qr/{code}` → detail screen; non-leaking 404 + offline states) |
| FR-028 — Asset search/filter (basic lookup + recent list) | Student 1 (Jayashan) | ✅ (`/assets/search`, reached from the dashboard's "Find an asset" field — which pre-fills `?q=` when the text isn't an exact code — or its filter icon; server-side server-side search by code/name/custom attribute, department/location/category/asset-type/status/condition filters, sorting and pagination via `GET /api/assets`; mock asset data supported) |
| FR-029 — Record asset condition | Student 1 (Jayashan) | ✅ (`features/assets/` — `PATCH /api/assets/{id}/condition` via the condition-update sheet, five-point scale, history written server-side; gated client-side to ACTIVE/UNDER_MAINTENANCE. **Role gap found, not yet fixed:** the backend restricts this endpoint to `CanManageAssets` — InventoryOfficer/Administrator — but `AssetDetailActions` shows the "Update Condition" button to any signed-in role once the lifecycle check passes; there's a `canVerifyAssetsProvider` gating Verify but no equivalent for condition update, so a Staff user sees and can tap a button the backend will 403 — an IF-02 gap) |
| FR-031 — Physical verification (presence/location/condition assertion) | Student 1 (Jayashan) | ✅ (`AssetVerificationScreen` at `/assets/:id/verify` — Officer-only in the router guard — submits the ad-hoc assertion via `POST /api/assets/{id}/verify`. Reached when an Officer starts verification (asset detail's Verify, or Scan to verify) for an asset with no pending campaign task, after a confirm dialog. Shares `VerificationForm` with FR-059. *Was unreachable until 2026-09-27 — the earlier ✅ here predated the route actually existing.*) |
| FR-033 — Fault report with photo evidence | Student 2 (Seneja) | ❌ |
| FR-037 — Maintenance status progress update | Student 2 (Seneja) | ❌ |
| FR-042 — Maintenance list/filter | Student 2 (Seneja) | ❌ |
| FR-043 — Raise transfer request | Student 3 (Bhanuka) | ❌ |
| FR-046 — Scan-to-confirm transfer receipt | Student 3 (Bhanuka) | ❌ |
| FR-058 — Verification task list, ordered by due date | Student 4 (Hasitha) | ✅ (`features/verification/` — the Verify tab at `/verification`, `GET /api/verification-tasks?mine=true`, grouped Overdue / Upcoming / Completed with counts; loading/empty/error/populated states. A Campaigns segment adds read-only campaign context — progress, scope, the officer's tasks in it — via the two `GET` campaign endpoints only; campaign management stays React-only per SRS §3.4) |
| FR-059 — Complete verification task via scan | Student 4 (Hasitha) | ✅ (**Scan is now enforced.** Verify tab / Home "Scan to verify" → scanner in identify mode (`/scan?purpose=identify`) → the officer's pending task for that asset opens already confirmed (`/verification/:taskId?scanned=1`); no task → offer ad-hoc (FR-031). Opening a task from the list instead requires "Scan asset" before *Present* can be submitted — a scan of a different asset is rejected with its code; *Not found* needs no scan. IF-10 manual code entry still works inside identify mode. Submits via `PATCH /api/verification-tasks/{id}/complete`; same `VerificationForm` as FR-031) |
| FR-061 — Raise discrepancy manually with photo | Student 4 (Hasitha) | ✅ (`RaiseDiscrepancyScreen` at `/verification/:taskId/discrepancy` — type/description/optional photo, compressed client-side to ≤1MB via `flutter_image_compress` (IF-11) before `POST /api/verification-tasks/photos` then `POST /api/verification-tasks/{taskId}/discrepancies`; backend role check widened to include InventoryOfficer — it was Auditor/Administrator-only, which would have 403'd every mobile call) |
| FR-067/069 — Initiate agentic evaluation, view workflow status | Student 4 (Hasitha) | ✅ (`features/workflows/` — `InitiateWorkflowScreen` at `/workflows/new` resolves an asset by code then `POST /api/agent-workflows`; `WorkflowListScreen`/`WorkflowDetailScreen` at `/workflows` and `/workflows/:id`, the latter polling `GET /api/agent-workflows/{id}` every 5s until resolved. This app never calls `/evaluate` or `/run-policy-agent` — those run inside the backend's own agent orchestration, not from a mobile trigger) |
| FR-076 — Display evaluation outcome | Student 4 (Hasitha) | ✅ (`WorkflowDetailScreen` — recommendation, approval status, high-impact flag, or the failure reason if the evaluation failed; no approval action, per the React-only responsibility boundary) |
| FR-080 — In-app notifications | Student 2 (Seneja) | ❌ |
| FR-083 — Task-focused dashboard | Student 4 (Hasitha) | ✅ (Home tab of the bottom-navigation shell, role-branched per §2.3.1. Officer: "Find an asset", at-a-glance counts, quick actions (report fault, request evaluation, campaigns, search), live previews of verification due / recent evaluations / my fault reports. Staff: "Find an asset", report fault / search, my fault reports. The previous hard-coded maintenance-assigned / transfers-awaiting sample rows were removed rather than shown as fake data — they come back as live sections once `features/maintenance` assignment and `features/transfers` exist. Role scoping still checked against `CoreGrid/doc/SRS/02-overall-description.md` §2.3.1) |

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
