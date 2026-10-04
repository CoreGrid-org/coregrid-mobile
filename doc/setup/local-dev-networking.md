# Local Development — Networking, TLS, and Running the Full Stack

How to get ThunderID, the CoreGrid backend, and this Flutter app talking to each other on one developer
machine, with the app running in an Android emulator (or a USB-connected physical device). Supersedes the
older `10.0.2.2`-based guidance in `CONTRIBUTING.md`/`mobile-specification.md` §5.1 — see
[Why not `10.0.2.2`](#why-not-1002) below.

## 1. Start the host-side services

| Service | Where | Command | Address |
|---|---|---|---|
| ThunderID + Postgres | `CoreGrid/` (see `doc/setup/ThunderID.md`) | first time: `docker compose -f oci://ghcr.io/thunder-id/thunderid-quick-start:latest -p coregrid up -d` then `docker compose up -d`; later: `docker compose start` / `docker start coregrid-thunderid-1` | `https://localhost:8090` (console at `/console`) |
| CoreGrid backend | `CoreGrid/backend/` | `dotnet run --launch-profile https` | `https://localhost:7240` |
| CoreGrid frontend (optional, not needed for mobile-only work) | `CoreGrid/frontend/` | `npm run dev` | `http://localhost:5173` |

Confirm the backend's Postgres connection (`ConnectionStrings:CoreGrid`, port `5433`) is up — it's the same
`coregrid-postgres` container the ThunderID compose file starts.

## 2. Forward the emulator/device to the host

Once per emulator boot (or per USB/adb connection to a physical device):

```bash
adb reverse tcp:8090 tcp:8090   # ThunderID
adb reverse tcp:7240 tcp:7240   # CoreGrid backend (https profile)
```

This makes `localhost:8090` and `localhost:7240` *inside* the emulator/device resolve to the same ports on
the host machine. Not persistent across emulator restarts — re-run after every boot. Works identically for
a USB-connected physical device, since `adb reverse` forwards over the adb connection itself, not over the
network.

## 3. Trust the dev TLS certs

Both ThunderID and the backend serve self-signed certs locally. Two separate trust surfaces need them:

### 3a. The app's own HTTP calls (dio, `flutter_appauth`'s discovery/token requests)

**dio** (every `/api/...` call, including `GET /api/me` at sign-in) runs on Dart's own `HttpClient`, which
does **not** read Android's network security config. In debug builds `lib/shared/api/dev_tls.dart` makes
dio accept the self-signed certs on host `localhost` only; release builds compile that out and validate
normally. Without it, sign-in succeeds but the dashboard says the CoreGrid role couldn't be loaded.

**`flutter_appauth`** (native Android networking) is governed by
`android/app/src/debug/res/xml/network_security_config.xml` (debug builds only — never merged into
release). It already trusts:

- `android/app/src/debug/res/raw/thunderid_dev_cert.pem` — ThunderID's cert, committed to the repo (fine to
  share — dev-only, not a secret), valid to 2027-08-09. Re-export it (see `CoreGrid/docs/setup/thunderid.md`)
  and replace this file only if the ThunderID container gets recreated with a new cert.
- `android/app/src/debug/res/raw/backend_dev_cert.pem` — the backend's `dotnet dev-certs https` cert. **This
  one is machine-specific and not portable** — each developer generates their own:

  ```bash
  dotnet dev-certs https -ep /tmp/backend-dev-cert.pfx -p devcert-export
  openssl pkcs12 -in /tmp/backend-dev-cert.pfx -clcerts -nokeys -out /tmp/backend-dev-cert.pem \
    -passin pass:devcert-export
  # Strip the "Bag Attributes"/"subject="/"issuer=" header lines openssl adds — Android's
  # resource parser wants a bare PEM block:
  sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' /tmp/backend-dev-cert.pem \
    > android/app/src/debug/res/raw/backend_dev_cert.pem
  rm /tmp/backend-dev-cert.pfx /tmp/backend-dev-cert.pem
  ```

  Because this file is machine-specific, **don't commit changes to it** beyond the placeholder already in
  the repo (each developer regenerates locally; if you need it gitignored properly, raise that rather than
  committing over a teammate's cert).

### 3b. The sign-in page itself (external user agent, SEC-ID-06)

ThunderID's hosted login page renders in the system browser via Custom Tabs, a separate process with its
own trust store — the network security config above does not cover it. Either:

- Click through Chrome's "Your connection is not private" interstitial each time (Advanced → Proceed) — dev
  only, harmless, no setup; or
- Install ThunderID's dev cert as a user CA once: `adb push android/app/src/debug/res/raw/thunderid_dev_cert.pem /sdcard/thunderid_dev_cert.pem`,
  then on the emulator: Settings → Security → Encryption & credentials → Install a certificate → CA
  certificate → select the pushed file.

## 4. Run the app

Put your three values in a gitignored `.env.json` at the repo root (copy `.env.example`) rather than
retyping `--dart-define` flags every run:

```json
{
  "API_BASE_URL": "https://localhost:7240",
  "THUNDERID_ISSUER": "https://localhost:8090",
  "THUNDERID_CLIENT_ID": "<dev Client ID from the ThunderID console — see thunderid-mobile-client.md>"
}
```

Then, with an emulator booted (or a device connected) and step 2's `adb reverse` already run against it:

```bash
flutter run --dart-define-from-file=.env.json
```

Equivalent without the file, if you'd rather pass the values directly:

```bash
flutter run \
  --dart-define=API_BASE_URL=https://localhost:7240 \
  --dart-define=THUNDERID_ISSUER=https://localhost:8090 \
  --dart-define=THUNDERID_CLIENT_ID=<dev Client ID from the ThunderID console — see thunderid-mobile-client.md>
```

`THUNDERID_ISSUER`, not `THUNDERID_BASE_URL` — matches the flag `AuthConfig`
(`lib/shared/auth/auth_config.dart`) actually reads. Passing
`THUNDERID_BASE_URL` is silently ignored: `AuthConfig.thunderIdIssuer` stays
empty, `AuthConfig.isConfigured` is `false`, and sign-in fails immediately
with "App isn't configured" rather than reaching ThunderID at all.

## Why not `10.0.2.2`? {#why-not-1002}

The Android emulator's `10.0.2.2` alias for the host's loopback still works as plain network reachability,
but it creates a hostname mismatch for OIDC: ThunderID is configured with a fixed issuer,
`ThunderID:Issuer = https://localhost:8090` (`CoreGrid/backend/appsettings.Development.json`), and its
discovery document and every token's `iss` claim assert that exact value. `flutter_appauth`'s underlying
AppAuth library requires the discovery document's declared `issuer` to match the URL it was fetched from —
if the app dialed `https://10.0.2.2:8090` instead, that check fails and sign-in never completes. Using
adb-reversed `localhost` on the device keeps the hostname identical to what every other client (backend,
React SPA) already uses, so there's nothing IdP-specific to reconcile. A physical device without an adb
connection (rare in practice — testing over wifi without `adb reverse`) is the one case that still needs
the host's LAN IP instead, with the same issuer-mismatch caveat applying there too.

## 6. Connecting an Expo app on a physical device

This repository is Flutter-based, but a companion Expo/React Native app can use the same local API during
development. A physical phone cannot resolve the development computer's `localhost`; use the computer's
LAN address or an adb reverse connection instead.

### 6a. Same Wi-Fi network

1. Put the phone and development computer on the same Wi-Fi network. Avoid guest Wi-Fi that blocks device-to-device traffic.
2. Find the computer's private LAN address (`ipconfig` on Windows, `ip addr` on Linux, or `ifconfig` on macOS).
3. Start the API so it listens on the LAN interface, not only loopback. For ASP.NET Core, use an HTTP development profile bound to `0.0.0.0`, for example:

   ```bash
   ASPNETCORE_URLS=http://0.0.0.0:5083 dotnet run --launch-profile http
   ```

4. Allow the selected port through the development computer's firewall.
5. Configure the Expo app with the computer's LAN address, not `localhost`:

   ```bash
   EXPO_PUBLIC_API_BASE_URL=http://192.168.1.42:5083 npx expo start
   ```

   Or place the same value in the Expo project's `.env` file:

   ```text
   EXPO_PUBLIC_API_BASE_URL=http://192.168.1.42:5083
   ```

6. Reload the Expo app and verify that a request to `/api/me` reaches the backend. The bearer token still comes from the normal ThunderID login; changing the API host does not bypass authentication.

### 6b. Android device over USB

If the Expo app is running on Android and the phone is connected over USB with USB debugging enabled, adb
reverse avoids exposing the API on the LAN:

```bash
adb devices
adb reverse tcp:5083 tcp:5083
```

Use `http://127.0.0.1:5083` in the Expo app. Repeat the reverse command after reconnecting the device.
For the HTTPS development profile, reverse both the API and ThunderID ports:

```bash
adb reverse tcp:7240 tcp:7240
adb reverse tcp:8090 tcp:8090
```

The Expo runtime must trust the local development certificate before using `https://127.0.0.1:7240`.
For local-only testing, the HTTP profile is simpler; never use an HTTP API URL in a production build.

### 6c. Expo and ThunderID caveat

ThunderID discovery validates its configured issuer. If the issuer is `https://localhost:8090`, a physical
phone using `https://192.168.1.42:8090` will fail issuer validation even when the port is reachable. For a
LAN-based Expo run, configure a development ThunderID issuer and certificate whose hostname is reachable
from the phone, register that issuer/client with ThunderID, and use the same value in the Expo environment.
Do not work around this by disabling TLS or issuer validation. The existing Flutter debug setup uses adb
reverse specifically so `localhost` remains consistent with ThunderID's configured issuer.

### 6d. Quick checks

```bash
# From the computer, confirm the API is listening on the intended interface.
curl http://127.0.0.1:5083/api/health

# From an Android shell, confirm adb-reversed access when applicable.
adb shell curl http://127.0.0.1:5083/api/health
```

If the first request succeeds but the phone request fails, check the firewall, Wi-Fi isolation, bind address,
and the URL loaded by Expo. If `/api/me` returns `401`, networking is working and the remaining issue is
authentication configuration rather than device connectivity.
