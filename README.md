# CoreGrid Mobile

The Flutter field-operations client for [CoreGrid](https://github.com/CoreGrid-org/CoreGrid) — scan an
asset, verify it, report a fault, confirm a transfer, right where you're standing.

This repository holds **only the app**. There's no backend here: it talks exclusively to the CoreGrid API
over HTTPS/REST, never to the database or the identity provider's management API directly. The backend, the
React admin console, and the authoritative requirements (SRS) all live in the main
[`CoreGrid`](../CoreGrid) repository.

React is the desk — administration, configuration, approvals, reporting. Flutter is the field — scanning,
verifying, reporting, confirming. That split is normative (`CoreGrid/doc/SRS/03-system-architecture.md`
§3.4), not a suggestion.

## Getting started

See [`CONTRIBUTING.md`](CONTRIBUTING.md) to set up the environment and run the app, and
[`doc/MOBILE-SPECIFICATION.md`](doc/MOBILE-SPECIFICATION.md) for the architecture, screen-by-screen flows,
and package choices. [`doc/PROGRESS.md`](doc/PROGRESS.md) tracks what's actually built.

## Stack

Flutter/Dart, Riverpod, `go_router`, `flutter_secure_storage`, `mobile_scanner`, `image_picker` — mandated
by the SRS (§2.5) and ADR-004. Android 8.0+ target; release APK for evaluation, no iOS in scope.

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
