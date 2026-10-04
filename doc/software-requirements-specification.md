# Software Requirements Specification

## CoreGrid Mobile

### Flutter Field Operations Client

**Version 1.1 | Mobile baseline**

Prepared as the mobile companion to the CoreGrid platform requirements. This document describes the scope, users, behaviour, interfaces, security, quality expectations, and evidence for this repository. The CoreGrid web/API repository remains authoritative for backend requirements and server-side policy.

| Item | Detail |
|---|---|
| Product | CoreGrid Mobile |
| Document type | Mobile software requirements specification |
| Platform | Flutter/Dart; Android is the supported target |
| API | CoreGrid ASP.NET Core API over HTTPS/REST |
| Identity | ThunderID OIDC/OAuth 2.0 with PKCE |
| State | Riverpod; authenticated API access through Dio |
| Baseline date | 2026-09-28 |
| Status | Working implementation baseline |

## 1. Purpose and scope

CoreGrid Mobile is the field client for authenticated users who need to identify and act on physical assets. It intentionally excludes administration, configuration, approval, reporting administration, and other web-console responsibilities.

The app must provide:

- authoritative asset lookup by QR code, asset code, or search;
- role-aware dashboards for Staff and Inventory Officers;
- inventory verification and discrepancy reporting;
- fault reporting with observed condition and optional photo evidence;
- maintenance work progress for assigned Inventory Officers;
- transfer-request creation, transfer detail, and QR-based receipt confirmation;
- workflow and notification views where the signed-in role has access; and
- secure sign-in, sign-out, role gating, organisation scoping, and useful offline/error states.

## 2. Users and permissions

| Role | Mobile access | Primary mobile responsibilities |
|---|---|---|
| Staff | Yes | Find assets and report faults within server-authorised scope. |
| Inventory Officer | Yes | Verification, discrepancy handling, maintenance progress, workflows, transfers, receipt confirmation, and fault reporting. |
| Administrator | No | Use the CoreGrid web console for administration and approval operations. |
| Auditor | No | Use the CoreGrid web console for read-only audit and reporting operations. |

Client-side gates improve usability only. The API remains the authority for authentication, organisation isolation, role permissions, status transitions, and ownership.

## 3. Functional requirements

| ID | Requirement | Acceptance summary |
|---|---|---|
| MOB-FR-001 | Authenticate | Sign in through ThunderID Authorization Code + PKCE; do not collect or store user passwords. |
| MOB-FR-002 | Maintain session | Keep the access token in memory, persist only the refresh token in secure storage, and support confirmed sign-out. |
| MOB-FR-003 | Resolve asset | Resolve a QR value or asset code through the API and display the authoritative asset record. |
| MOB-FR-004 | Search assets | Search authorised assets with server-side paging and clear empty/error states. |
| MOB-FR-005 | Role dashboard | Render only the dashboard content appropriate to the authenticated role. |
| MOB-FR-006 | Verify asset | Allow an Inventory Officer to complete the supported verification workflow and record discrepancies. |
| MOB-FR-007 | Report fault | Select an authorised asset, record condition and description, optionally upload compressed photo evidence, and submit a fault report. |
| MOB-FR-008 | Maintenance progress | Show assigned maintenance records and allow the supported mobile status transition. |
| MOB-FR-009 | Request transfer | Select an authoritative asset by scan or search, choose a destination department and location, submit the request, and open its created detail record. |
| MOB-FR-010 | Confirm receipt | Scan the asset at receipt and call the transfer confirmation endpoint for the current transfer ID. |
| MOB-FR-011 | Notifications | Display the signed-in user's notifications and unread state when available from the API. |
| MOB-FR-012 | Recover from failure | Translate network/API failures into plain-language states with retry actions and no raw exception leakage. |

## 4. Non-functional requirements

- Security: all API requests use the shared authenticated client; secrets and tokens must not be committed.
- Privacy: mobile endpoints must remain organisation- and user-scoped by the API.
- Usability: primary actions must be discoverable, labels must be concise, forms must validate before submission, and loading/error/empty states must be explicit.
- Accessibility: controls require readable labels, adequate touch targets, contrast, and semantic tooltips where an icon is the only affordance.
- Reliability: API operations must handle timeout, offline, unauthorized, forbidden, not-found, and server-failure responses without crashing the app.
- Maintainability: feature API clients, models, providers, screens, and widgets remain grouped by feature; shared authentication and API behaviour stays centralized.
- Performance: QR resolution and common asset lookups should show immediate progress and render the authoritative result without unnecessary duplicate requests.

## 5. Architecture and interfaces

The application is structured as a feature-first Flutter client:

```text
lib/app/                 router, app shell, and application bootstrap
lib/features/            auth, assets, dashboards, maintenance, transfers, and workflows
lib/shared/              API client, authentication, theme, and UI kit
test/                    unit and widget tests
doc/                     product, setup, ownership, and implementation documentation
```

External calls are made through feature API classes over the shared Dio client. The client attaches the in-memory bearer token from `AuthController`. Feature providers expose asynchronous data and mutation state to screens. `go_router` owns application navigation and role guards.

Key interfaces include:

| Interface | Purpose |
|---|---|
| `GET /api/me` | Resolve the signed-in profile, role, organisation, and workplace. |
| `GET /api/assets` and `GET /api/assets/qr/{code}` | Search and resolve assets. |
| `POST /api/assets/{id}/verify` | Complete an asset verification. |
| `POST /api/maintenance/faults` | Create a fault report. |
| `POST /api/maintenance/photos` | Upload compressed photo evidence. |
| `POST /api/transfers` | Create a transfer request. |
| `GET /api/transfers/{id}` | Fetch one transfer detail record. |
| `POST /api/transfers/{id}/confirm-receipt` | Confirm receipt after QR identification. |

## 6. Data and validation

All request models use the API's snake_case JSON contract. IDs are treated as opaque strings. A selected asset must come from the authoritative asset API response; forms must not submit a display code in place of the asset ID. Destination location options are loaded only after selecting a department and are reset when the department changes.

Forms must validate required fields before calling a mutation. Photo evidence is compressed before upload. API responses are parsed into typed models and provider caches are invalidated after successful mutations.

## 7. Security and configuration

Runtime configuration is provided through `--dart-define-from-file` or equivalent environment defines. Required values include `API_BASE_URL`, `THUNDERID_ISSUER`, and `THUNDERID_CLIENT_ID`. Local development certificate trust is limited to debug builds and local hosts. Production builds must use standard certificate validation.

AI coding assistants may be used during development under CoreGrid SRS §18.6: the author reviews, tests and understands every AI-proposed change before committing it, and never shares secrets or private data with an AI tool.

## 8. Verification plan

| Area | Evidence |
|---|---|
| Models and parsing | Dart unit tests for enums, request serialization, and API response parsing. |
| Providers and APIs | Tests with controlled Dio/Riverpod dependencies and error cases. |
| Screens | Flutter widget tests for validation, loading, empty, error, and navigation states. |
| Authentication | Manual ThunderID sign-in, role-gate, sign-out, and API authorization checks. |
| Device flows | Android QR scan, camera permission, local networking, photo selection, and API submission. |

## 9. Document control

| Version | Date | Owner | Change |
|---|---|---|---|
| 0.1 | 2026-08-17 | Hasitha Erandika | Mobile project documentation initialized. |
| 0.2 | 2026-09-15 | Hasitha Erandika | Dashboard, onboarding, authentication, and setup documentation aligned with implementation. |
| 0.3 | 2026-09-27 | CoreGrid team | Asset, maintenance, notification, transfer, workflow, and role flows documented. |
| 1.0 | 2026-09-28 | Hasitha Erandika | Mobile SRS and lowercase documentation index. |
| 1.1 | 2026-10-04 | Hasitha Erandika | Product-only baseline: team roster, AI-use disclosure and commit-history appendices moved out of the product documentation; component ownership now follows the main CoreGrid SRS §12. |

## 10. Ownership and contribution

Feature ownership follows the component maintainers in the main CoreGrid SRS (§12, Component Ownership): `features/assets/` and `features/scan/` (Component A), `features/maintenance/` and `features/notifications/` (B), `features/transfers/` (C), and the app shell, authentication, dashboards, `features/verification/` and `features/workflows/` (D). Development workflow, review and change control follow CoreGrid SRS §18 and [`CONTRIBUTING.md`](../CONTRIBUTING.md).
