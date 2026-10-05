# Demo Deployment — Release APK

How to build, publish and install the APK for the CoreGrid live demo. The general rules for any release build
(HTTPS, app identity, launcher icon) are in [`release-build.md`](release-build.md); this page fills them in
for the demo environment.

## 1. Target environment

| | Value |
|---|---|
| API | `https://coregrid-v7jn.onrender.com` (Render) |
| ThunderID issuer | `https://coregrid-1.onrender.com` (Render) |
| ThunderID client | **CoreGrid Mobile** (public client, PKCE, redirect `com.coregrid.mobile://auth-callback`) |
| Web app (same accounts) | https://demo-coregrid.vercel.app |

Both servers already meet the release requirements: they serve HTTPS with publicly trusted certificates, and
the CoreGrid Mobile client is registered in the hosted ThunderID with the app's redirect scheme. Nothing
needs changing on the server side.

Mobile demo accounts. The password for both is `Login@123456`:

| Account | Role |
|---|---|
| `officer@coregrid.test` | Inventory Officer |
| `staff@coregrid.test` | Department Staff |

Administrator and Auditor accounts are web-only by design. The app shows them the Access-restricted screen.

## 2. Configuration

The four values live in `.env.demo.json` at the repository root. It is git-ignored by the `.env.*` rule.
None of the values is a secret, but they are environment-specific, so they stay out of the code (SRS §5.1):

```json
{
  "API_BASE_URL": "https://coregrid-v7jn.onrender.com",
  "THUNDERID_ISSUER": "https://coregrid-1.onrender.com",
  "THUNDERID_CLIENT_ID": "<CoreGrid Mobile client ID>",
  "THUNDERID_APPLICATION_ID": "<CoreGrid Mobile application ID — enables password reset>"
}
```

`API_BASE_URL` is the bare origin. The app adds `/api/...` itself, and strips an accidental trailing `/api`.

## 3. Build locally

```bash
flutter clean && flutter pub get
flutter analyze && flutter test
flutter build apk --release --dart-define-from-file=.env.demo.json
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. Before each new build, bump the `+BUILD`
number in `pubspec.yaml` (for example `1.0.0+1` → `1.0.0+2`). Otherwise Android refuses to install the new
APK over an older one with the same build number.

## 4. Build in CI (optional)

On a push to `main`, `.github/workflows/ci.yml` builds the release APK from repository secrets and uploads it
as an artifact. To target the demo, set these under **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `PROD_API_BASE_URL` | `https://coregrid-v7jn.onrender.com` |
| `PROD_THUNDERID_ISSUER` | `https://coregrid-1.onrender.com` |
| `PROD_THUNDERID_CLIENT_ID` | the CoreGrid Mobile client ID |
| `PROD_THUNDERID_APPLICATION_ID` | the CoreGrid Mobile application ID |

## 5. Publish

1. Rename the APK for the submission, for example `SE3090_G<NN>.apk`.
2. Attach it to a GitHub Release on this repository, tagged to match `pubspec.yaml`, with release notes. Also
   upload it wherever the submission links point.
3. Record the link in the group report's submission links.

## 6. Install and smoke test

1. On the Android device, allow installs from the browser or file manager, then open the APK.
2. Open the web app or `https://coregrid-v7jn.onrender.com/health` first. The demo runs on Render's free tier
   and sleeps when idle, so the first request can take about a minute.
3. Sign in as `officer@coregrid.test`, then check:
   - the dashboard loads
   - scanning an asset QR code opens the asset
   - a verification campaign shows its checklist
   - **Evaluate** starts an agent workflow that then appears in the web app for the Administrator
4. Sign in as `staff@coregrid.test` and report a fault with a photo.

## 7. Troubleshooting

| Symptom | Cause |
|---|---|
| "App isn't configured with ThunderID/API values" at sign-in | The build ran without `--dart-define-from-file=.env.demo.json`. |
| Sign-in page never loads, or times out | ThunderID was asleep. Retry after a minute. |
| Signed in, but every screen fails | The API was asleep, or `API_BASE_URL` points somewhere else. |
| "App not installed" | Same or lower `+BUILD` number than the installed APK, or a different signing key. Uninstall the old app first. |
