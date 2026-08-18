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
No feature folders yet — `lib/features/` is still empty; each owner creates their own per
`CONTRIBUTING.md`. No ThunderID PKCE sign-in yet (`features/auth/` not started), so the app currently boots
to a placeholder home screen with no real routes.

## Legend

✅ Done &nbsp;·&nbsp; 🟡 Partial &nbsp;·&nbsp; ❌ Not started

## By requirement

| Requirement | Owner | Status |
|---|---|---|
| FR-001/007/008 — Sign in/out via ThunderID PKCE, role-aware nav, sign-out clears session | Student 4 (Hasitha) | ❌ |
| FR-020 — Attribute-driven asset detail rendering | Student 1 (Jayashan) | ❌ |
| FR-024 — QR scan → authoritative asset record within 3s | Student 1 (Jayashan) | ❌ |
| FR-025 — Manual asset-code entry fallback | Student 1 (Jayashan) | ❌ |
| FR-028 — Asset search/filter (basic lookup + recent list) | Student 1 (Jayashan) | ❌ |
| FR-029 — Record asset condition | Student 1 (Jayashan) | ❌ |
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
| FR-083 — Task-focused dashboard | Student 4 (Hasitha) | ❌ |

## Next milestone

Vertical slice: `flutter create`, project skeleton per `CONTRIBUTING.md`, ThunderID PKCE sign-in against a
running CoreGrid backend, and one read-only screen (asset detail via manual code entry) to prove the
API-only communication path end-to-end before building the scanner.
