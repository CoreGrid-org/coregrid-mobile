# CoreGrid Mobile — notes for AI-assisted sessions

CoreGrid Mobile is the Flutter field-operations client for CoreGrid, an asset-lifecycle management system.
This repository is **client-only** — no backend, no database, no identity-provider code. It talks
exclusively to the ASP.NET Core Web API that lives in the sibling `CoreGrid` repository
(`../CoreGrid/backend/`), over HTTPS/REST, and never calls the database, ThunderID's management API or the
agentic-AI service directly (SRS constraint C-05).

The requirements this app implements are specified in the main repository, not here — treat
[`../CoreGrid/doc/SRS/`](../CoreGrid/doc/SRS/00-front-matter.md) as authoritative, and
[`../CoreGrid/doc/PROGRESS.md`](../CoreGrid/doc/PROGRESS.md) as the current build-status source of truth for
the whole platform. This repo's own [`doc/PROGRESS.md`](doc/PROGRESS.md) tracks only the mobile slice.
Assume both repositories are checked out as siblings under the same parent directory — relative links
between them depend on that layout.

Most relevant SRS sections for this app: §2.5 (C-04, C-05 — mandated stack and API-only rule), §3.4 (the
React/Flutter responsibility boundary — normative, not descriptive), §4.3/§4.8/§4.9 (PKCE with external user
agent, token storage, SEC-ID-06/07), §5.1–5.2 (IF-02 through IF-13 — UI and hardware interface
requirements), and the Flutter-tagged rows of §6 (FR-024, FR-025, FR-031, FR-033, FR-037, FR-046, FR-058,
FR-059, FR-061, FR-067, FR-076, FR-083).

**[`doc/MOBILE-SPECIFICATION.md`](doc/MOBILE-SPECIFICATION.md)** is the implementation-level companion to
the above — package selection, the Riverpod/go_router/dio patterns to follow, every screen's flow and API
calls, environment/build flavors, and the CI pipeline. Read it before scaffolding or adding a screen; it's
the concrete "how" behind the SRS's "what". It is not itself part of the baselined SRS, so update it freely
as the app is actually built — no scope-change process required for this file.

**[`doc/TEAM-ALLOCATION.md`](doc/TEAM-ALLOCATION.md)** says which group member owns which `lib/features/`
folder. If you're picking up work in this repo, check it before touching a feature that isn't clearly
unowned — building someone else's assigned FR range without coordination is the kind of overlap SE3090's
individual-contribution rules (main SRS §12.1) specifically penalise.

## Conventions worth knowing

- **Responsibility boundary is normative.** Before adding a screen or capability, check SRS §3.4's table.
  If it reads "React: Yes / Flutter: No" for that capability, it does not belong in this app — raise a
  scope change instead of building it here.
- **State management is Riverpod** (ADR-004) — don't introduce Provider, BLoC, or setState-with-a-service-
  locator patterns; they were considered and rejected.
- **Auth uses an external user agent, never an embedded WebView** (RFC 8252, SEC-ID-06) — the user must see
  the identity provider's own address bar. Refresh tokens go in `flutter_secure_storage` (Android Keystore
  backed); access tokens stay in memory only. Never write a token to shared preferences or application logs.
- **Camera permission degrades gracefully** (IF-10) — a refused permission falls back to manual asset-code
  entry, it never dead-ends the flow.
- **Fault-report photos are compressed to ≤1MB before upload** (IF-11) — do this client-side before the
  network call, not server-side.
- **Both clients share one set of business rules**, enforced only by the API (AR-1, C-07) — this app
  validates client-side for immediate feedback (IF-03) but must never assume that validation is sufficient;
  always surface server-side field errors too.
- **No client hardware dependency beyond camera** is required for the baseline (IF-13) — don't reach for
  location, biometrics, Bluetooth or NFC without a corresponding SRS requirement.

## Before finishing mobile work

- `flutter analyze` — zero issues.
- `flutter test` — passing.
- If you touched anything auth-related: confirm no token or secret is written to logs (SEC-ID-05) and that
  sign-out clears local state (SRS §4.8).
- If you touched the API base URL or ThunderID client config: update `doc/setup/` here, not just local
  `.env`/config files, so the next session doesn't have to rediscover it.
