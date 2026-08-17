# Contributing to CoreGrid Mobile

This repository holds the Flutter field-operations client only. It has no backend of its own — it is
useless without a running instance of the API in the sibling [`CoreGrid`](../CoreGrid) repository. Set that
up first via [`CoreGrid/CONTRIBUTING.md`](../CoreGrid/CONTRIBUTING.md) (infrastructure, ThunderID, backend,
database) before working here.

## Prerequisites

- Flutter 3.x SDK (stable channel) and Dart, on your `PATH` — `flutter doctor` should report no blocking
  issues.
- Android SDK with a platform ≥ API 26 (Android 8.0) and at least one emulator or a physical device with USB
  debugging enabled — this is the app's minimum target (SRS §2.4).
- A running CoreGrid backend + ThunderID instance (see the main repo's `CONTRIBUTING.md`), reachable from
  the device or emulator you're testing against. An Android emulator reaches the host machine's `localhost`
  via `10.0.2.2`, not `127.0.0.1` — a physical device needs the host's LAN IP instead.

## 1. Clone

Clone this repository as a sibling of `CoreGrid`, so relative doc links and any shared tooling assumptions
hold:

```
Projects/
  CoreGrid/          # backend + web frontend + SRS
  coregrid-mobile/   # this repo
```

## 2. Register the mobile client in ThunderID

The mobile app is a **public client** — no client secret is embedded in the APK. Register it in ThunderID
as a mobile/native application with a custom-scheme redirect URI and PKCE (SRS Appendix C, item 4). Record
the client ID and redirect scheme in `doc/setup/` here, not in code or committed config — see
[`CoreGrid/doc/setup/ThunderID.md`](../CoreGrid/doc/setup/ThunderID.md) for how the equivalent React
registration was done.

## 3. Configure the API base URL

Point the app at your local backend (see step 1 above for the emulator-vs-device host address). Keep this
in an untracked local config (e.g. `--dart-define`, a gitignored `.env`) — never hardcode an environment-
specific URL into source that gets committed.

## 4. Install dependencies and run

```bash
flutter pub get
flutter run
```

## 5. Before committing

```bash
flutter analyze   # zero issues
flutter test      # passing
```

## Project Structure

This repo starts empty — run `flutter create .` to scaffold the standard Flutter project layout (`lib/`,
`android/`, `pubspec.yaml`, etc.). The full `lib/` layout, package selection, and per-feature responsibilities
are specified in [`doc/MOBILE-SPECIFICATION.md`](doc/MOBILE-SPECIFICATION.md) §2–§3 — read that before
scaffolding, rather than improvising a structure. If you're a group member picking a feature to start on,
[`doc/TEAM-ALLOCATION.md`](doc/TEAM-ALLOCATION.md) says which one is already yours. In short: one
`lib/features/<name>/` folder per capability,
owning its own screens, Riverpod providers, and API calls together (never split into global `screens/`,
`providers/`, `services/` trees), mirroring the ownership-boundary rule the backend and React frontend
already follow ([`CoreGrid/CONTRIBUTING.md` § Project Structure](../CoreGrid/CONTRIBUTING.md#project-structure)).

**Adding a new feature:** create `lib/features/<name>/`, wire its routes into `app/`'s `go_router`
configuration, add its row to `doc/MOBILE-SPECIFICATION.md` §4 and §8, and put anything another feature will
also need (a shared widget, a base API client) in `shared/` rather than reaching into another feature's
folder.

## Code Comments

Default to no comments — a well-named widget, provider, and file already say what the code does. Add one
only when it captures a non-obvious *why* (a ThunderID/API constraint, an SRS requirement, a workaround for
a specific platform bug), a hidden invariant, or something genuinely surprising about the behaviour.

## Need Help?

See [`CoreGrid/CONTRIBUTING.md`](../CoreGrid/CONTRIBUTING.md) for backend/infrastructure setup, and
[`CoreGrid/doc/SRS/`](../CoreGrid/doc/SRS/00-front-matter.md) for the requirements this app implements.
