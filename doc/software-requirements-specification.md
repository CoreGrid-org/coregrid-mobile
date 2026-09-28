# Software Requirements Specification

## CoreGrid Mobile

### Flutter Field Operations Client

**Version 1.0 | Mobile baseline**

Prepared as the mobile companion to the CoreGrid platform requirements. This document describes the scope, users, behaviour, interfaces, security, quality expectations, and evidence for this repository. The CoreGrid web/API repository remains authoritative for backend requirements and server-side policy.

| Item | Detail |
|---|---|
| Product | CoreGrid Mobile |
| Document type | Mobile software requirements specification |
| Platform | Flutter/Dart; Android evaluation target |
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

External AI tools may assist development only when their use is disclosed, reviewed, tested, understood, and recorded. No external AI assistant is to be used during the demonstration or viva; only CoreGrid's own agentic subsystem may run during evaluation.

## 8. Verification plan

| Area | Evidence |
|---|---|
| Models and parsing | Dart unit tests for enums, request serialization, and API response parsing. |
| Providers and APIs | Tests with controlled Dio/Riverpod dependencies and error cases. |
| Screens | Flutter widget tests for validation, loading, empty, error, and navigation states. |
| Authentication | Manual ThunderID sign-in, role-gate, sign-out, and API authorization checks. |
| Device flows | Android QR scan, camera permission, local networking, photo selection, and API submission. |
| Documentation | Links resolve to the lowercase documentation files and commit appendix matches `git log --all`. |

## 9. Document control

| Version | Date | Owner | Change |
|---|---|---|---|
| 0.1 | 2026-08-17 | Hasitha Erandika | Mobile project documentation initialized. |
| 0.2 | 2026-09-15 | Hasitha Erandika | Dashboard, onboarding, authentication, and setup documentation aligned with implementation. |
| 0.3 | 2026-09-27 | CoreGrid team | Asset, maintenance, notification, transfer, workflow, and role flows documented. |
| 1.0 | 2026-09-28 | Hasitha Erandika | Mobile SRS, lowercase documentation index, AI-use policy, and complete repository commit evidence added. |

## 10. Team roster

| Student | Name | Primary area |
|---|---|---|
| Student 1 | Jayashan Guruge | Asset registry, QR identification, verification, and mobile asset UI. |
| Student 2 | Seneja Ramanayaka | Maintenance, notifications, and related mobile integration. |
| Student 3 | Bhanuka Samarasinghe | Transfer/disposal domain and transfer mobile implementation. |
| Student 4 | Hasitha Erandika | Authentication, organisation configuration, integration, dashboards, documentation, and release support. |

Student IDs, GitHub handles, and emails remain placeholders until supplied by the named members.

## 11. AI usage disclosure

CoreGrid follows this rule: **AI proposes → owner reviews the diff → owner tests it → owner understands it → Git records it.** AI-generated code is not accepted without review. Each student is responsible for maintaining their own tool/model, date, task, accepted/rejected output, and verification record.

| Date | Tool/model | Scope | Verification |
|---|---|---|---|
| 2026-09-28 | Codex | Audited mobile documentation, standardized documentation filenames, rewrote the README, and organized this SRS/commit appendix. | Reviewed repository paths, cross-checked links, inspected `git log --all`, and did not create a commit. |

Any member-specific AI record must be expanded in the submitted assessment report with the exact tool/model used. No owner may claim work they cannot explain, modify, test, or debug.

## Appendix A — Repository commit history

The following table is generated from `git log --all` for this repository at the time of this documentation update. It records commit messages as evidence; merge commits and revert commits are intentionally retained.

| Commit | Date | Author | Message |
|---|---|---|---|
| `f077d49` | 2026-09-28 | HasithaErandika | revert: bhanuka merged tasks |
| `e754e07` | 2026-09-28 | Jayashan | Merge pull request #11 from CoreGrid-org/task/ui-enhancement |
| `d2f24a3` | 2026-09-28 | Jayashan | style(ui): apply simple orange and white theme to dashboard and surfaces |
| `5f25914` | 2026-09-27 | Hasitha Erandika | Merge pull request #10 from CoreGrid-org/feature/notify_maintenance |
| `9a8a2d2` | 2026-09-27 | seneja | refactor(transfers): clean up obsolete transfer screens and models |
| `7d0a59a` | 2026-09-27 | seneja | chore: update app routing, auth config tests, and specifications |
| `958572b` | 2026-09-27 | seneja | feat(notifications): introduce notifications feature |
| `4c303fc` | 2026-09-27 | seneja | feat(maintenance): enhance fault reporting, add maintenance records view and update officer actions |
| `91df428` | 2026-09-27 | HasithaErandika | feat: add org config with password reset by thunderID issuer |
| `736555c` | 2026-09-27 | Hasitha Erandika | Merge pull request #8 from CoreGrid-org/feature/transfer-request-and-receipt |
| `caa1fa3` | 2026-09-27 | Hasitha Erandika | Merge branch 'development' into feature/transfer-request-and-receipt |
| `e8d3d92` | 2026-09-27 | HasithaErandika | feat: shell UI improvements |
| `635f6db` | 2026-09-27 | HasithaErandika | feat: improve UIUX and design revamp |
| `2a1b9a3` | 2026-09-27 | HasithaErandika | fix: local auth certificate validations |
| `9ef8100` | 2026-09-27 | NipunaBhanuka18 | feat(mobile): implement FR-043 (initiate transfer) and FR-046 (scan-to-confirm receipt) |
| `1c72182` | 2026-09-26 | HasithaErandika | fix(auth): request roles scope and show why /api/me failed |
| `3c62524` | 2026-09-26 | HasithaErandika | refactor(assets): fold search/verify into AssetsApi and fix tests |
| `c5258c2` | 2026-09-26 | HasithaErandika | fix(auth): return to the app after ThunderID sign-in |
| `2eb218d` | 2026-09-25 | Jayashan | Merge pull request #7 from CoreGrid-org/fix/asset_feature |
| `6fafa96` | 2026-09-25 | Jayashan | fix: enable ad hoc asset verification without a pending task |
| `7d649da` | 2026-09-25 | Jayashan | Merge pull request #6 from CoreGrid-org/fix/frontend-issues |
| `abb6ad0` | 2026-09-25 | Jayashan | add comments |
| `a607e9c` | 2026-09-25 | Jayashan | add report fault feature and  improve ui |
| `0608a65` | 2026-09-25 | Jayashan | fix ui/ux staff dashbaord |
| `d3f1acc` | 2026-09-25 | HasithaErandika | docs: update tasks to the backend implementations refctor |
| `9bff166` | 2026-09-16 | Jayashan | Merge pull request #4 from CoreGrid-org/feature/asset |
| `878282c` | 2026-09-16 | Jayashan | feat: add QR asset scanning flow |
| `9a4c2ba` | 2026-09-16 | Jayashan | Merge pull request #3 from CoreGrid-org/feature/asset |
| `0bd5ae8` | 2026-09-16 | Jayashan | feat(mobile): implement asset verification workflow and improve Ui/Ux related Asset and Discrepancy |
| `6f300b4` | 2026-09-15 | Jayashan | wire asset search page with backend |
| `dc792b6` | 2026-09-15 | Jayashan | improve asset ui/ux |
| `3c7eb3d` | 2026-09-15 | HasithaErandika | feat: remove dev bypass and improve mobile UI, add onbording screens. |
| `1eec808` | 2026-09-15 | HasithaErandika | feat: init the basic dashboards map with verification and workflows. |
| `760943f` | 2026-09-15 | HasithaErandika | docs: correct the setup Docs |
| `52d91b1` | 2026-09-09 | Hasitha Erandika | Merge pull request #1 from CoreGrid-org/feature/asset-registry-qr |
| `3efcf76` | 2026-09-09 | Jayashan | Update progress.md |
| `ee8003f` | 2026-09-09 | Jayashan | implement FR-020,FR-028 ,FR-029,FR-031 asset registry |
| `7f3a475` | 2026-08-18 | HasithaErandika | feat: Update setup with ThunderID and Dev Pass for Dashboards for Inventory Officer + Staff |
| `e6ab745` | 2026-08-18 | HasithaErandika | feat: Flutter mobile core init |
| `f18a333` | 2026-08-17 | HasithaErandika | chore: project doc init. |

## Appendix B — AI review checklist

- [ ] The named owner reviewed the resulting diff.
- [ ] The owner ran the relevant tests or documented why they could not run.
- [ ] The owner checked security, authorization, and data-scoping implications.
- [ ] The owner understands the final implementation.
- [ ] The owner recorded the tool, model, task, accepted/rejected output, and verification.
- [ ] No external AI assistant will be used during the demonstration or viva.

*End of Software Requirements Specification — CoreGrid Mobile, Version 1.0.*
