# Release Build — Checklist

What must be true before building a `staging`/`prod` APK. Local development is unaffected by everything
here — see [`local-dev-networking.md`](local-dev-networking.md) for that.

## 1. Server side (outside this repo)

- **HTTPS with a publicly trusted certificate** for both the CoreGrid API and ThunderID. Release builds
  validate certificates normally (the `localhost` bypass in `lib/shared/api/dev_tls.dart` and the debug
  `network_security_config.xml` are debug-only), block cleartext HTTP (`usesCleartextTraffic="false"` in
  `android/app/src/main/AndroidManifest.xml`), and refuse to sign in if `API_BASE_URL` or
  `THUNDERID_ISSUER` isn't `https://` (`AuthConfig.usesHttps`).
- **A mobile client registered in that environment's ThunderID** — public/native client, PKCE, redirect URI
  `com.coregrid.mobile://auth-callback`. Same steps as the dev client in
  [`thunderid-mobile-client.md`](thunderid-mobile-client.md), against the staging/prod ThunderID instance.

## 2. App identity — confirm before the first release

The application ID `com.coregrid.mobile` (`android/app/build.gradle.kts`) is still marked a placeholder in
`mobile-specification.md` §5.2. Once an APK is installed on users' devices, or published to Play, it
**cannot change** without them reinstalling as a new app. If it changes, change these together:

- `applicationId` and the `appAuthRedirectScheme` manifest placeholder in `android/app/build.gradle.kts`
- `AuthConfig.redirectUrl` in `lib/shared/auth/auth_config.dart`
- the redirect URI registered in every environment's ThunderID client

## 3. Build

All three required values, from the target environment (never committed — keep them in a gitignored
`.env.<env>.json`):

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://<api host> \
  --dart-define=THUNDERID_ISSUER=https://<thunderid host> \
  --dart-define=THUNDERID_CLIENT_ID=<client ID for this environment> \
  --dart-define=THUNDERID_APPLICATION_ID=<application ID — optional, enables password reset>
```

Bump the `+BUILD` number in `pubspec.yaml` for every release build (§5.2).

## 4. Launcher icon

Generated from `assets/branding/coregrid.webp`: an adaptive icon (`mipmap-anydpi-v26/ic_launcher.xml`,
white background + `ic_launcher_foreground.png`) plus legacy `ic_launcher.png` fallbacks. If the logo
changes, regenerate every `mipmap-*` density — the foreground is a 108dp canvas with the logo kept inside
the central 66dp safe zone so launcher masks don't clip it.
