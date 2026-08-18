# Local Development — Networking, TLS, and Running the Full Stack

How to get ThunderID, the CoreGrid backend, and this Flutter app talking to each other on one developer
machine, with the app running in an Android emulator (or a USB-connected physical device). Supersedes the
older `10.0.2.2`-based guidance in `CONTRIBUTING.md`/`MOBILE-SPECIFICATION.md` §5.1 — see
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

Governed by `android/app/src/debug/res/xml/network_security_config.xml` (debug builds only — never merged
into release). It already trusts:

- `android/app/src/debug/res/raw/thunderid_dev_cert.pem` — ThunderID's cert, committed to the repo (fine to
  share — dev-only, not a secret), valid to 2027-08-09. Re-export it (see `CoreGrid/doc/setup/ThunderID.md`)
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

```bash
flutter run \
  --dart-define=API_BASE_URL=https://localhost:7240 \
  --dart-define=THUNDERID_BASE_URL=https://localhost:8090 \
  --dart-define=THUNDERID_CLIENT_ID=<dev Client ID from the ThunderID console — see ThunderID-mobile-client.md>
```

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
