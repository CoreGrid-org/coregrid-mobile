# CoreGrid Mobile

CoreGrid Mobile is the Flutter field-operations client for the CoreGrid asset lifecycle platform. It gives authenticated Staff and Inventory Officers a focused mobile workflow for finding assets, scanning QR labels, verifying inventory, reporting faults, requesting transfers, confirming receipt, and reviewing assigned work.

This repository contains the mobile client only. The CoreGrid API and web administration console are maintained in the main CoreGrid repository. The app communicates with the API through HTTPS/REST and never connects directly to PostgreSQL or ThunderID management endpoints.

## Product boundary

- Staff use the mobile app to find assets and report faults.
- Inventory Officers use the mobile app for verification, maintenance progress, workflows, transfers, receipt confirmation, and fault reporting.
- Administrators and Auditors use the web console; they are not mobile roles.
- ThunderID provides OIDC/OAuth 2.0 authentication.
- CoreGrid applies organisation and role scoping in the API.

## Technology

- Flutter and Dart
- Riverpod for state management
- go_router for navigation
- Dio for authenticated API access
- flutter_appauth and flutter_secure_storage for authentication
- mobile_scanner for QR identification
- image_picker for photo evidence
- Android is the supported evaluation target.

## Documentation

- [Mobile specification](doc/mobile-specification.md) — architecture, requirements, routes, API contracts, and traceability.
- [Progress](doc/progress.md) — implementation status and known gaps.
- [Team allocation](doc/team-allocation.md) — ownership and contribution boundaries.
- [Software requirements specification](doc/software-requirements-specification.md) — mobile SRS, document control, AI-use disclosure, and repository commit evidence.
- [Asset detail notes](doc/features/asset-detail.md) — asset detail flow and implementation notes.
- [Local networking](doc/setup/local-dev-networking.md) — Android device, HTTPS, and adb reverse setup.
- [ThunderID mobile client](doc/setup/thunderid-mobile-client.md) — redirect URI and client registration requirements.
- [Contributing](CONTRIBUTING.md) — development workflow and project conventions.

## Quick start

Install Flutter, Android Studio, and the Android SDK, then fetch dependencies:

```bash
flutter pub get
```

Copy the example configuration and provide the development API and ThunderID values:

```bash
cp .env.example .env.json
```

Use the commands and local certificate setup in [local networking](doc/setup/local-dev-networking.md). Then run:

```bash
flutter run --dart-define-from-file=.env.json
```

Run the test suite with:

```bash
flutter test
```

Before opening a pull request, also run:

```bash
dart analyze
```

Use `flutter analyze` instead if the Flutter SDK is the configured analyzer entry point.

## Repository layout

```text
lib/app/                 Application shell and router
lib/features/            Auth, assets, dashboards, maintenance, transfers, and workflows
lib/shared/              API client, authentication, theme, and reusable widgets
test/                    Unit and widget tests
doc/                     Product, setup, ownership, and implementation documentation
android/                 Android application and development certificate configuration
```

## Security and configuration

Never commit `.env.json`, client secrets, access tokens, refresh tokens, or private certificates. The API client attaches the in-memory ThunderID access token to requests. Development-only certificate trust is restricted to local hosts; production builds must use normal certificate validation.

## License

Apache License 2.0. See [LICENSE](LICENSE).
