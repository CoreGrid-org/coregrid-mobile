# CoreGrid Mobile — Application Specification

This document consolidates everything specific to the Flutter client into one place, in the same style as
the main [`CoreGrid` SRS](../../CoreGrid/doc/SRS/00-front-matter.md) chapters (see e.g. Chapter 17, Chapter
18). It is **not** part of the baselined SRS itself — that document lives in the main repository and any
change to it goes through the scope-change process described in its front matter (§00). This is an
implementation-level companion, scoped entirely to this repository, and it can change freely as the app is
actually built without touching the main repo's change-control process.

Numbering below (`§1`–`§8`) is local to this document only; it does not correspond to SRS chapter numbers.

## 1. Purpose and Scope

Defines the concrete engineering decisions for CoreGrid Mobile that the SRS states as constraints but does
not itself prescribe at implementation level: exact package selection, code-organisation patterns, the
screen-by-screen behaviour of every Flutter-owned requirement, build/environment configuration, and the CI
pipeline. Requirements themselves — the *what* and *why* — remain owned by the SRS; this document is the
*how*, and defers to the SRS wherever the two could be read as disagreeing.

## 2. Architecture and Package Selection

### 2.1 Mandated stack

Fixed by SRS §2.5 (C-04) and ADR-004 — not open to substitution without a scope change:

| Package | Role |
|---|---|
| `flutter_riverpod` | State management and dependency injection |
| `go_router` | Declarative routing, role-aware guards |
| `flutter_secure_storage` | Refresh-token storage (Android Keystore-backed) |
| `mobile_scanner` | QR/barcode decoding via the rear camera |
| `image_picker` | Camera/photo-library access for fault-report evidence |

### 2.2 Supporting packages

Not individually mandated by the SRS, but needed to satisfy specific requirements. Pin exact versions in
`pubspec.yaml` at `flutter create` time — no versions are pinned here, so this list doesn't go stale against
whatever is current when the project is actually scaffolded.

| Package | Satisfies | Purpose |
|---|---|---|
| `dio` | — | HTTP client with interceptor support, used for the typed API client (§3.4) |
| `riverpod_generator` + `build_runner` | — | Code-generated, type-safe providers; reduces Riverpod boilerplate |
| `freezed` + `json_serializable` | IF-03 | Immutable DTOs and union types for API models and form/validation state |
| `flutter_appauth` | SEC-ID-06, §4.3 (main SRS) | OIDC Authorization Code + PKCE via external user agent (RFC 8252) — do not hand-roll PKCE |
| `flutter_image_compress` | IF-11 | Client-side compression of fault-report photos to ≤1MB before upload |
| `permission_handler` | IF-10 | Requesting and checking camera permission with a plain-language rationale |
| `connectivity_plus` | — | Detecting offline state to surface a clear network-error state (IF-01-equivalent for mobile lists) |
| `intl` | — | Date/number formatting consistent with the backend's culture settings |
| `shared_preferences` | — | Device-local flags that aren't secrets and don't need Keystore backing — e.g. the onboarding-seen flag (§4.0). Not for tokens; those stay in `flutter_secure_storage` per §3.4/CLAUDE.md |

Resolved in favour of `--dart-define` (see §5) over `flutter_dotenv` for environment configuration — no
`.env`-parsing package is in `pubspec.yaml`.

Deliberately **not** used: any BLoC/Provider/GetX state-management package (superseded by ADR-004), any
embedded-WebView OAuth package (violates RFC 8252 / SEC-ID-06), any local database/ORM for offline
persistence (offline capture is an explicit Future Enhancement per the main SRS Chapter 17 — the baseline is
online-only).

## 3. Application Architecture

### 3.1 Layering

```
lib/
  app/                     Entry point, ProviderScope root, go_router configuration
  features/<name>/         One folder per capability — see CONTRIBUTING.md for the full list
    <name>_providers.dart   Riverpod providers for this feature's state
    <name>_api.dart          API calls this feature owns, using the shared client
    screens/                 One file per screen
    widgets/                 Feature-local widgets not reused elsewhere
  shared/
    api/                     ApiClient (dio instance + auth interceptor), typed error model
    auth/                    Token storage, PKCE flow, AuthState provider, route-guard helpers
    widgets/                 Cross-feature widgets (loading/empty/error states, confirmation dialog for IF-05)
    theme/                   App theming
```

A feature folder owns its screens, its providers, and its API calls together — never split into global
`screens/`, `providers/`, `services/` trees. This mirrors the ownership-boundary rule the backend and React
frontend already follow (main repo `CONTRIBUTING.md` § Project Structure).

### 3.2 State management pattern

Riverpod `AsyncNotifier`/`Notifier` per feature-level concern, not per screen — a screen reads from one or
more providers rather than owning its own state:

```dart
@riverpod
class AssetLookup extends _$AssetLookup {
  @override
  Future<Asset?> build() => null;

  Future<void> lookupByCode(String code) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(assetsApiProvider).getByCode(code));
  }
}
```

Screens consume this via `ref.watch(assetLookupProvider)` and switch on `AsyncValue`'s `loading` / `error` /
`data` cases to drive the loading/empty/error/populated states IF-01 requires of the web client and that
this app applies by the same principle, even though IF-01 itself is scoped to React.

### 3.3 Routing and role guards

`go_router`'s `redirect` callback enforces IF-02 (unpermitted actions neither rendered nor reachable) at the
route level, reading permissions from the same `/api/me` response the backend already returns:

```dart
GoRoute(
  path: '/verify/:assetId',
  builder: (context, state) => VerificationScreen(assetId: state.pathParameters['assetId']!),
  redirect: (context, state) =>
      ref.read(authStateProvider).hasPermission('asset:verify') ? null : '/unauthorized',
),
```

Route table mirrors the feature list in §3.1 one-to-one — no route lives outside its feature's folder.

### 3.4 API client and auth interceptor

One shared `dio` instance (`shared/api/api_client.dart`) with a single auth interceptor:

- Attaches the in-memory access token as `Authorization: Bearer <token>` on every request.
- On a `401`, attempts exactly one silent refresh using the stored refresh token, then retries the original
  request once; a second `401` signs the user out and routes to `/sign-in`, preserving unsaved form input
  where practical (main SRS §4.8).
- Surfaces backend field-level validation errors (a `400` with a structured error payload) as a typed
  exception the calling provider can map to per-field form errors (IF-03) — never as a raw exception message
  shown to the user (IF-09).
- Never logs the request/response body when it contains a token, consistent with SEC-ID-05.

## 4. Screen-by-Screen Flow Specification

Each row is one screen or flow; "States" follows the same loading/empty/error/populated vocabulary the SRS
uses for React list views (IF-01), applied here for consistency even where the mobile-specific requirement
doesn't spell it out.

### 4.0 Onboarding (not an SRS requirement)

| | |
|---|---|
| Trigger | App cold start, before sign-in — the router's `initialLocation` |
| Sequence | Three-page swipeable intro (Scan & Identify / Verify & Report / Stay On Top of Your Day) → Sign In, or auto-skipped straight to §4.1 once already seen |
| States | Page N of 3, skip |
| API calls | None — a device-local flag (`OnboardingStorage`) records that it's been shown, so it only ever appears once per install |
| Status | Live (`features/onboarding/`) — a UX addition to the app-shell owner's scope, not tied to any FR/IF requirement. Kept out of §8's traceability table for that reason; it's listed here so it isn't mistaken for an undocumented gap. |

### 4.1 Authentication — FR-001, FR-008, SEC-ID-06

| | |
|---|---|
| Trigger | App cold start with no valid session, or explicit sign-out |
| Sequence | Splash → sign-in button → external browser (ThunderID) → redirect back via custom scheme → token exchange → `/api/me` → role check → dashboard, or `/access-restricted` |
| States | Signing in, sign-in failed (non-technical message, retry), role not supported, signed out |
| API calls | Token exchange via ThunderID (not the CoreGrid API directly); `GET /api/me` on success |

**No registration screen — by design, not by omission.** This app never creates an account. Every CoreGrid
user is provisioned by an Administrator through the React console's Users & Roles page
(`POST /api/users`, `ManageUsers` policy — Administrator only), which is how ThunderID's `CoreGridUser`
identity gets an `ExternalSubjectId` linked to a `Users` row and a role in the first place. `features/auth/`
here is sign-in-only: there is no "Create account"/"Sign up" affordance anywhere in this app, and none
should be added — building one would duplicate Administrator-only functionality that's explicitly
React-only per the responsibility boundary (main SRS §3.4), and ThunderID itself has no self-registration
enabled for this deployment. A user with no CoreGrid account yet simply cannot sign in to this app; that's
expected, not a bug to fix here.

**Role gate (main SRS §3.4, scope change v1.5):** ThunderID's `CoreGridUser` type is shared by all four
roles — there is no way to restrict *sign-in* to specific roles at the identity-provider level — so this app
enforces the split itself, after `GET /api/me` resolves `role`. Officer and Staff proceed to the dashboard;
Auditor and Administrator land on `/access-restricted` instead (`features/auth/screens/
access_restricted_screen.dart`), and their refresh token is cleared immediately rather than left valid —
an unsupported role never counts as a real mobile session. Mirrors the React frontend's own
`/access-restricted` route (`CoreGrid/doc/setup/ThunderID.md`). The full role-to-platform picture — why each
role uses the client(s) it does, and how both clients integrate with ThunderID and the API — is
`CoreGrid/doc/SRS/03-system-architecture.md` §3.4.1 (Figure 10).

### 4.2 Dashboard — FR-083

| | |
|---|---|
| Trigger | Successful sign-in, or app resume with a valid session |
| Sequence | Role-branched (main SRS §2.3.1): Officer sees verification tasks due, maintenance assigned, transfers awaiting confirmation; Staff sees their own fault reports and status only — narrower, since Staff has no verification/maintenance-management/transfer capability |
| States | Loading, empty (per section — "No tasks due"), error (per section, independently retryable), populated |
| API calls | Aggregated from the verification, maintenance and transfer list endpoints (main SRS §9), scoped to the current user |
| Status | **Partially live** (`features/dashboard/screens/{dashboard,officer_dashboard,staff_dashboard}_screen.dart`) — "Verification Tasks Due" reads real data from `features/verification/`; "Maintenance Assigned to Me" and "Transfers Awaiting My Confirmation" stay hardcoded sample rows until `features/maintenance`/`features/transfers` exist to back them, disclosed with an on-screen banner. |

### 4.3 Scan / Manual Entry — FR-024, FR-025, IF-06, IF-07, IF-10, IF-12

| | |
|---|---|
| Trigger | "Scan Asset" — the primary action on the dashboard |
| Sequence | Camera preview (`mobile_scanner`) → decode → resolve → asset detail. A visible "Enter code manually" affordance is present from the start, not only after a failure, and is what's shown directly if camera permission is refused |
| States | Requesting permission, scanning, resolving (must return a result or a clear failure within 3s per IF-06), not found, manual-entry form |
| API calls | `GET /api/assets/qr/{code}` |

### 4.4 Asset Detail — FR-020, FR-029

| | |
|---|---|
| Trigger | Successful scan or manual lookup |
| Sequence | Attribute-driven read view (rendered from the type's attribute definitions, no hardcoded domain knowledge — same rule as the React client, FR-020) with entry points to Verify, Report Fault, and — if the asset's current lifecycle state allows it — Condition update |
| States | Loading, error (asset not found / not accessible to this user's department), populated |
| API calls | `GET /api/assets/{id}` (`GET /api/assets/qr/{code}` when reached by code instead of ID — same detail screen either way); condition update is `PATCH /api/assets/{id}/condition`, gated client-side to ACTIVE/UNDER_MAINTENANCE, via the condition-update bottom sheet. That endpoint is `CanManageAssets`-gated server-side — InventoryOfficer/Administrator only, **not** Staff — so the "Update Condition" button must only render for InventoryOfficer, the same way `canVerifyAssetsProvider` already gates the Verify button (see `doc/PROGRESS.md` FR-029 for a currently-open gap where this isn't yet enforced client-side) |

### 4.5 Physical Verification — FR-031, FR-059, FR-061

Two distinct backend endpoints exist for this, but as of this writing only one is actually reachable from
the app — read this section as "intended design" for FR-031's row, and check `doc/PROGRESS.md` before
assuming both paths work:

| | |
|---|---|
| Trigger (intended, FR-031) | "Verify" from asset detail should offer ad hoc verification independent of any campaign task |
| Trigger (**actual, today**) | Asset detail's "Verify" button (Officer only, `canVerifyAssetsProvider`) looks up the current user's pending verification *task* for that asset and opens it — **or** opening a task directly from the verification-task list (FR-059, `features/verification/`). If there's no pending task for the asset, the user gets a message pointing them at the task list; there's no fallback to a true ad hoc verification today |
| Sequence | Assert presence → assert location (defaults to registered location, editable) → assert condition → submit → result screen showing whether a discrepancy was raised |
| States | In progress (multi-step, must survive backgrounding without losing entered state), submitting, discrepancy raised, no discrepancy, submission error |
| API calls (intended) | Ad hoc: `POST /api/assets/{id}/verify` (`AssetVerificationScreen`, `features/assets/`). Task-bound: `PATCH /api/verification-tasks/{id}/complete` (`VerificationTaskDetailScreen`, `features/verification/`). Both run the same comparison server-side (see below) and both return whether a discrepancy was raised — the response shape differs (asset vs. task payload), so the two screens can't share one API call even though they'd share the same form widget |
| API calls (**actual, today**) | Only the task-bound path is reachable. `AssetVerificationScreen` and its `verifyAsset()` call exist and are widget-tested in isolation, but nothing in `lib/` navigates to it — it isn't in `app/router.dart` and isn't called from `AssetDetailActions` either. Verifying an asset with no open campaign task isn't possible from the running app today. |
| Server-side logic | Neither endpoint auto-corrects the register. If asserted "not present" → raises `Missing` and stops (location/condition aren't checked for an asset that isn't there). Otherwise: asserted location ≠ registered location → `LocationMismatch`; asserted condition ≠ registered condition → `ConditionMismatch`. Raised `Open`, `is_automatic = true`, no `raised_by` user. `Surplus`/`DataMismatch`/`Other` can't be produced this way — see FR-061 below. |
| Note | Officer only (main SRS scope change v1.5) — Auditor no longer completes verification tasks via mobile scan; Auditor reviews results on the web console instead |

**Manual discrepancy — FR-061 (task-bound only; `RaiseDiscrepancyScreen`):** a two-call submission, not one —
`POST /api/verification-tasks/photos` first (uploads the optional evidence photo, compressed client-side to
≤1MB per IF-11, returns a URL) then `POST /api/verification-tasks/{taskId}/discrepancies` with that URL,
`type` (any of `Missing / Surplus / LocationMismatch / ConditionMismatch / DataMismatch / Other` — this is
the only path that can raise `Surplus`/`DataMismatch`/`Other`, since the two endpoints above can't infer
them), and a description. Raised `Open`, `is_automatic = false`, `raised_by` = the reporting officer.
Resolution (`Open` → `Resolved`, `PATCH /api/discrepancies/{id}/resolve`) is Auditor/Administrator-only and
is not a mobile screen — it happens on the web console.

### 4.6 Fault Reporting — FR-033, IF-05, IF-11

| | |
|---|---|
| Trigger | "Report Fault" from asset detail |
| Sequence | Description → observed condition → optional photo (camera or library, compressed client-side to ≤1MB) → confirmation naming the asset (IF-05) → submit |
| States | Draft, photo compressing, submitting, submitted, error (with the draft preserved for retry) |
| API calls | If a photo was attached: `POST /api/maintenance/photos` first (returns a URL), then `POST /api/maintenance/faults` with `asset_id`, `description` (≤2000 chars), `observed_condition`, and that photo URL. **Not** the generic `POST /api/maintenance` — that endpoint is InventoryOfficer-only and would 403 for Staff, who file the majority of fault reports. The fault-report record always starts unassigned (`assignee_id` is never set here) — see §4.7 for how it gets assigned. |

### 4.7 Maintenance Task Progress — FR-037, FR-042

| | |
|---|---|
| Trigger | From the dashboard's assigned-maintenance section or a filtered list |
| Sequence | List (status/priority/date filters) → record detail → legal-transition-only status update (illegal transitions not offered as options, not merely rejected server-side) |
| States | Loading, empty, error, populated; update-in-flight |
| API calls | `GET /api/maintenance` (filtered — filter to `assignee_id = me` for "my work"), then one of the three transition endpoints below depending on the record's current status |

**Status transitions** (`REQUESTED → APPROVED → IN_PROGRESS → COMPLETED`, or `CANCELLED` from any
non-terminal state) — there is no generic `/status` endpoint; each transition is its own call:

| Transition | Endpoint | Who |
|---|---|---|
| `REQUESTED → APPROVED` | `POST /api/maintenance/{id}/approve` | InventoryOfficer/Administrator — see "Assigned to", below |
| `APPROVED → IN_PROGRESS` | `POST /api/maintenance/{id}/start` | InventoryOfficer/Administrator |
| `IN_PROGRESS → COMPLETED` | `POST /api/maintenance/{id}/complete` | **InventoryOfficer only** — Administrator is deliberately excluded from this one endpoint (every other transition uses the InventoryOfficer-or-Administrator policy); since Administrator has no mobile access anyway (§4.1's role gate), this asymmetry doesn't affect this app in practice, but don't assume the same role set applies to every transition if extending this screen |
| any → `CANCELLED` | `POST /api/maintenance/{id}/cancel` | InventoryOfficer/Administrator, optional reason |

**How "Assigned to" gets set — there is no separate assign action.** Assignment happens exclusively as part
of Approve: `POST /api/maintenance/{id}/approve` takes both `assignee_id` and `estimated_cost` in the same
call and sets them together with the status flip to `APPROVED`. There's no reassignment afterwards — Amend
(`PUT /api/maintenance/{id}`) only touches type/priority/description, never the assignee — and `Start` is
rejected server-side if the record has no assignee yet. So on mobile: a Staff-filed fault report or an
Officer-created record sits `REQUESTED` and unassigned until an InventoryOfficer/Administrator approves it
(picking an assignee from the org's users, no role restriction on who can be chosen), at which point it
appears in that assignee's "Maintenance Assigned to Me" dashboard section. Completing a record additionally
requires `estimated_cost`/`actual_cost`, ≥10-character `work_performed`, a `completion_date`, and a
`resulting_condition` — build that as a real form, not a bare "Mark complete" button.

### 4.8 Transfer Request & Receipt Confirmation — FR-043, FR-046

| | |
|---|---|
| Trigger | "Raise Transfer" from asset detail, or "Confirm Receipt" from the dashboard's awaiting-confirmation section |
| Sequence (raise) | Destination department → destination location → reason → submit |
| Sequence (confirm) | Scan the incoming asset (reuses §4.3) → confirm receipt → asset returns to ACTIVE at the new department/location |
| States | Both flows: draft, submitting, submitted, error |
| API calls | Raise: `POST /api/transfers`, InventoryOfficer/Administrator only (`CanRequestTransfer`). Confirm: `POST /api/transfers/{id}/confirm-receipt`, InventoryOfficer/Administrator only (`CanConfirmReceipt`) — both policies exclude Staff and Auditor, so on this Officer-only-mobile app there's no extra role gating to add beyond §4.1's. Approve/reject (`POST /api/transfers/{id}/approve`, `/reject`) are Administrator-only and out of scope for this app entirely. |

### 4.9 Agentic Workflow Status — FR-067, FR-069, FR-076

| | |
|---|---|
| Trigger | "Request Evaluation" from asset detail; workflow status from a notification or the dashboard |
| Sequence | Initiate (states objective, receives a workflow ID immediately — does not block on completion) → status screen (current step, agents completed) → outcome screen (recommendation + approval status) once resolved |
| States | Initiating, in progress (polled or pushed), outcome available, failed |
| API calls | `POST /api/agent-workflows`, `GET /api/agent-workflows/{id}` (`AgentWorkflowsController` — this section previously said `/api/workflows`, the route name before the backend controller landed) |
| Note | No approval action here — approval is React-only per the responsibility boundary (main SRS §3.4). Officer only — Administrator initiates and Auditor/Administrator view workflow status from the web console instead (scope change v1.5); this screen is unreachable for those roles per §4.1's role gate |

### 4.10 Notifications — FR-080

| | |
|---|---|
| Trigger | Notification icon/badge from any screen |
| Sequence | List, most recent first, unread visually distinguished; tapping one navigates to the relevant asset/task/workflow, and marks it read |
| States | Loading, empty, error, populated |
| API calls | `GET /api/notifications` for the list; `GET /api/notifications/unread-count` for the badge (poll or refresh on app resume — there's no push channel); `PATCH /api/notifications/{id}/read` on tap-through; `PATCH /api/notifications/read-all` for a "mark all read" action |

## 5. Environment and Build Configuration

### 5.1 Flavors

Three configurations, selected at build time via `--dart-define`, not committed source:

| Flavor | API base URL | ThunderID client |
|---|---|---|
| `dev` | `https://localhost:7240`, reached via `adb reverse` — see `doc/setup/local-dev-networking.md` for why this replaces the `10.0.2.2` emulator alias (it avoids an OIDC issuer-URL mismatch against ThunderID) and the TLS-trust setup it needs | Dev-registered mobile client (doc/setup/ThunderID-mobile-client.md) |
| `staging` | Deployed staging API | Staging-registered mobile client |
| `prod` | Deployed production API | Production-registered mobile client |

Recommended: copy `.env.example` to a gitignored `.env.json` with your real values, then:

```bash
flutter run --dart-define-from-file=.env.json
```

Equivalent without the file:

```bash
flutter run \
  --dart-define=API_BASE_URL=https://localhost:7240 \
  --dart-define=THUNDERID_ISSUER=https://localhost:8090 \
  --dart-define=THUNDERID_CLIENT_ID=<dev Client ID from the ThunderID console>
```

Read these via `String.fromEnvironment` in `shared/api/` and `shared/auth/` — never hardcode a URL or client
ID in source that gets committed, and never commit a `.env`/`.env.json` file containing them (see
`.gitignore`).

### 5.2 App identity and versioning

- Application ID: `com.coregrid.mobile` (placeholder — confirm against the actual ThunderID redirect-scheme
  registration in `doc/setup/ThunderID-mobile-client.md` before changing either, since they must match).
- Version scheme: semantic `MAJOR.MINOR.PATCH+BUILD` in `pubspec.yaml`, `BUILD` incremented on every release
  build regardless of whether `MAJOR.MINOR.PATCH` changed.

### 5.3 Signing

Local development and `dev`-flavor builds run unsigned/debug. A release keystore for `staging`/`prod` builds
is generated once, stored outside the repository, and referenced from `android/key.properties` — which is
gitignored and never committed, the same rule as any other secret in this repository.

## 6. CI/CD Pipeline

Matches the main repo's stated CI approach (its own SRS §3.3: GitHub Actions, "additional jobs for the React
build and Flutter analyse"). Once `flutter create` has been run, add this as
`.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main, development]
  pull_request:
    branches: [main, development]

jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version-file: pubspec.yaml
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test

  build-apk:
    needs: analyze-and-test
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version-file: pubspec.yaml
      - run: flutter pub get
      - run: >
          flutter build apk --release
          --dart-define=API_BASE_URL=${{ secrets.PROD_API_BASE_URL }}
          --dart-define=THUNDERID_CLIENT_ID=${{ secrets.PROD_THUNDERID_CLIENT_ID }}
      - uses: actions/upload-artifact@v4
        with:
          name: coregrid-mobile-release
          path: build/app/outputs/flutter-apk/app-release.apk
```

`analyze-and-test` gates every push and pull request to `main`/`development`, matching the branch names
already used in the main repo. `build-apk` runs only on `main`, and reads environment-specific values from
repository secrets — never from a committed `--dart-define` value, consistent with §5.1.

## 7. Testing Strategy

| Layer | Tool | Scope |
|---|---|---|
| Unit / provider | `flutter_test` + Riverpod's `ProviderContainer` | Business logic in `*_providers.dart` and API-mapping logic, independent of widgets |
| Widget | `flutter_test` | Individual screens/widgets in isolation, with providers overridden to fixed states (loading/error/populated) |
| Manual golden-path | — | The scan → verify and scan → transfer-confirm sequences, run against a real running backend before each release build, since these are the flows IF-06/IF-07 hold to a 3-second, one-handed usability bar that an automated test can't assess |

Out of scope for the baseline: automated integration/end-to-end tests driving a real device, and golden-image
screenshot tests. Neither is required by the SRS, and both would add CI time disproportionate to a
single-evaluator Android APK deliverable (main SRS §2.4).

## 8. Traceability

Maps each Flutter-owned requirement to the module that satisfies it, for quick lookup — current build
status lives in [`PROGRESS.md`](PROGRESS.md), not here; this table doesn't change as work progresses. The
**Owner** column is the same per-feature assignment as
[`TEAM-ALLOCATION.md`](TEAM-ALLOCATION.md) — see that file for why, not just who.

| Requirement | Module (§) | Owner |
|---|---|---|
| FR-001, FR-008, SEC-ID-06 | `shared/auth/` (§4.1) | Student 4 (Hasitha) — app shell |
| FR-020 | `features/assets/` (§4.4) | Student 1 (Jayashan) |
| FR-024, FR-025, IF-06, IF-07, IF-10, IF-12 | `features/scan/` (§4.3) | Student 1 (Jayashan) |
| FR-028 | `features/assets/` (basic lookup only — advanced search/filter/export is React-only per SRS §3.4) | Student 1 (Jayashan) |
| FR-029 | `features/assets/` (§4.4) | Student 1 (Jayashan) |
| FR-031 | `features/assets/` — the ad hoc `POST /api/assets/{id}/verify` path (§4.5), not `features/scan/` — the asset-detail entry point doesn't depend on a scanner existing | Student 1 (Jayashan) — this component's named business-specific operation. Built but not yet routed — see `doc/PROGRESS.md` |
| FR-058, FR-059, FR-061 | `features/verification/` (§4.5) | Student 4 (Hasitha) |
| FR-033, IF-11 | `features/maintenance/` (§4.6) | Student 2 (Seneja) |
| FR-037, FR-042 | `features/maintenance/` (§4.7) | Student 2 (Seneja) |
| FR-043, FR-046 | `features/transfers/` (§4.8) | Student 3 (Bhanuka) |
| FR-083 | `features/dashboard/` (§4.2) | Student 4 (Hasitha) — built last, once other features exist to summarise |
| FR-067, FR-069, FR-076 | `features/workflows/` (§4.9) | Student 4 (Hasitha) — "agent status display" per main SRS §12 |
| FR-080 | `features/notifications/` (§4.10) | Student 2 (Seneja) — same FR-077–080 range as this owner's backend notification service |
| IF-02, IF-05, IF-09 | Cross-cutting — `shared/widgets/`, `shared/auth/` route guards, `shared/api/` error mapping | Student 4 (Hasitha) — shell/shared |
| IF-03 | Cross-cutting — form validation pattern in every feature's screens | Each feature's own owner |
| IF-13 | Constraint, not a module — no location/biometric/Bluetooth/NFC code in the baseline | — |
