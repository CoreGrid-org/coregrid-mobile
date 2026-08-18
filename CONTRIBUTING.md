# Contributing to CoreGrid Mobile

This repository holds the Flutter field-operations client only. It has no backend of its own — it is
useless without a running instance of the API in the sibling [`CoreGrid`](../CoreGrid) repository. Set that
up first via [`CoreGrid/CONTRIBUTING.md`](../CoreGrid/CONTRIBUTING.md) (infrastructure, ThunderID, backend,
database) before working here.

## Prerequisites

- Flutter 3.x SDK (stable channel) and Dart, on your `PATH` — `flutter doctor` should report no blocking
  issues. See [flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install) for the
  platform-specific installer, or follow one of the three setups below.
- Android SDK with a platform ≥ API 26 (Android 8.0) and at least one emulator or a physical device with USB
  debugging enabled — this is the app's minimum target (SRS §2.4). Installed via
  [Android Studio](https://developer.android.com/studio) on every platform.
- A running CoreGrid backend + ThunderID instance (see the main repo's `CONTRIBUTING.md`), reachable from
  the device or emulator you're testing against. Use `adb reverse` to forward the emulator's (or a
  USB-connected physical device's) `localhost` to the host's `localhost` — see
  [`doc/setup/local-dev-networking.md`](doc/setup/local-dev-networking.md) for the full runbook, including
  why this is preferred over the `10.0.2.2` emulator alias (it avoids an OIDC issuer-URL mismatch against
  ThunderID) and the TLS-trust setup both ThunderID and the backend's self-signed dev certs need.

Run `flutter doctor -v` after any of the setups below and resolve everything under the Flutter and Android
toolchain sections before continuing; the web/desktop sections it also prints don't matter for this repo
(SRS §2.4 — Android APK is the only baseline target).

### Linux

1. Download the Flutter SDK tarball and extract it somewhere under your home directory (not
   `/usr/local`, which needs `sudo` for every `flutter upgrade`), e.g. `~/development/flutter`.
2. Add it to `PATH` in `~/.bashrc` or `~/.zshrc`: `export PATH="$HOME/development/flutter/bin:$PATH"`.
3. Install Android Studio (JetBrains Toolbox or the `.tar.gz` from the link above), open it once so it
   installs the Android SDK, then accept licenses: `flutter doctor --android-licenses`.
4. Install the packages Gradle needs to build: `sudo apt install clang cmake ninja-build libgtk-3-dev` (only
   `clang`/build tooling from this list is actually required for the Android-only build in this repo — the
   rest is what `flutter doctor` asks for if it also probes Linux-desktop support, which this repo doesn't
   use).
5. For a physical device over USB, Ubuntu/Debian generally work without extra udev rules; if `adb devices`
   doesn't see your phone, see
   [developer.android.com/studio/run/device](https://developer.android.com/studio/run/device) for the
   distro-specific udev rule.

### macOS

1. Either `brew install --cask flutter` or download the SDK zip from the link above and extract it, e.g. to
   `~/development/flutter`.
2. Add it to `PATH` in `~/.zshrc` (the default shell): `export PATH="$HOME/development/flutter/bin:$PATH"`.
3. Install Android Studio, open it once to install the Android SDK, then
   `flutter doctor --android-licenses`.
4. Xcode is **not** needed for this repo — it's only required for iOS/macOS targets, and this app is
   Android-only (SRS §2.4). Ignore any Xcode-related line in `flutter doctor` output.
5. Physical Android devices work over USB without extra driver installation on macOS.

### Windows

1. Download the Flutter SDK zip from the link above and extract it to a short path with no spaces, e.g.
   `C:\src\flutter` — a path under `C:\Users\<you>\...` with spaces or a very long path can hit Windows'
   `MAX_PATH` limit during `flutter pub get`.
2. Add `C:\src\flutter\bin` to your `Path` under System Properties → Environment Variables (not the
   PowerShell session-only `$env:Path`, which won't persist).
3. Enable Developer Mode (Settings → Privacy & Security → For developers) — the Flutter tool needs it to
   create symlinks even for an Android-only build; without it, `flutter doctor` reports an error about
   symlink support.
4. Install Android Studio, open it once to install the Android SDK, then
   `flutter doctor --android-licenses` from PowerShell.
5. For a physical device over USB, install your phone manufacturer's USB driver (Google's own driver for
   Pixel devices is available through the Android Studio SDK Manager → SDK Tools → Google USB Driver).
6. Clone this repo (and the sibling `CoreGrid` repo) to a short path too, e.g. `C:\src\Projects\`, for the
   same `MAX_PATH` reason as step 1.

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
flutter emulators --launch Pixel_6 
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
