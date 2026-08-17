# CoreGrid Mobile

The Flutter field-operations client for [CoreGrid](https://github.com/CoreGrid-org/CoreGrid), a configurable,
agentic-AI-assisted asset lifecycle management platform for government & institutional assets.

This repository holds **only the Flutter application**. There is no backend here — CoreGrid Mobile talks
exclusively to the ASP.NET Core Web API in the main [`CoreGrid`](../CoreGrid) repository over HTTPS/REST; it
never touches the database, the identity provider's management API or the agentic-AI service directly
(SRS constraint C-05). The Software Requirements Specification — the authoritative source for every
requirement this app implements — also lives in the main repository, at
[`CoreGrid/doc/SRS/`](../CoreGrid/doc/SRS/00-front-matter.md).

## What this app is for

CoreGrid draws a hard line between its two clients: React is the management and control centre for users
at a desk making a decision; Flutter is the field operations application for users standing in front of an
asset recording a fact (SRS §3.4). Concretely, CoreGrid Mobile is the QR scan → verify → report → confirm
application:

| Capability | Notes |
|---|---|
| Sign in / sign out | ThunderID via OIDC Authorisation Code + PKCE, external user agent (RFC 8252) |
| QR asset scan | Primary action on the dashboard — result or failure within 3s (IF-06, FR-024) |
| Manual asset-code entry | Fallback when scanning isn't possible or camera permission is refused (FR-025, IF-10) |
| Physical verification | Assert presence, location and condition against the register (FR-031, FR-059) |
| Fault reporting | Description, condition, optional photo, compressed to ≤1MB (FR-033, IF-11) |
| Maintenance progress | Update status on a request already raised — no assignment/costing (FR-037) |
| Transfer receipt confirmation | Scan-to-confirm on arrival at the destination department (FR-046) |
| Task list | Outstanding verification tasks and assigned maintenance, by due date (FR-058, FR-083) |
| Agentic workflow status | Initiate an evaluation and see its outcome — no approval authority (FR-067, FR-076) |
| Notifications | In-app list, unread state (FR-080) |

What it deliberately does **not** do — user/role administration, department/location/category
configuration, asset creation beyond condition/location, transfer/disposal approval, verification campaign
management, reports/export, agentic approval decisions — is reserved for the React web application. The
full capability boundary is normative, not descriptive: SRS §3.4 has the complete table, and any proposal
to move a capability across it is a scope change, not a mobile-app decision.

## Tech stack

Mandated by SRS §2.5 (C-04) and recorded in ADR-004:

- **Flutter 3** / Dart
- **Riverpod** — state management (compile-time-safe DI, testable providers, no service-locator boilerplate)
- **go_router** — declarative routing, role-aware route guards (IF-02)
- **flutter_secure_storage** — refresh token storage, backed by the Android Keystore (SEC-ID-06)
- **mobile_scanner** — QR decoding via the rear camera (IF-10)
- **image_picker** — camera/photo-library access for fault-report evidence (IF-11)

Target: Android 8.0 (API 26) and above; release APK built for evaluation (SRS §2.4). The Flutter codebase is
cross-platform, but only Android is evidenced for the baseline — no iOS release is in scope.

Full detail — package selection, code layout, every screen's flow, environment/build config and the CI
pipeline — is in [`doc/MOBILE-SPECIFICATION.md`](doc/MOBILE-SPECIFICATION.md).

## Repository layout

This is a fresh repository — see [`CONTRIBUTING.md`](CONTRIBUTING.md) for how to get started once
`flutter create` has been run.

| Path | Contents |
|---|---|
| `doc/MOBILE-SPECIFICATION.md` | Architecture, packages, screen-by-screen flows, environment/build config, CI pipeline |
| `doc/TEAM-ALLOCATION.md` | Who owns which `lib/features/` folder, mapped from the main SRS's component ownership |
| `doc/PROGRESS.md` | What's actually built here vs. still planned — treat as more current than assumptions about this repo |
| `doc/setup/` | Environment setup notes specific to the mobile client (ThunderID client registration, API base URL) |

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
