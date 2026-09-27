# ThunderID — Mobile Client Registration

The web application's ThunderID setup is documented in
[`CoreGrid/doc/setup/ThunderID.md`](../../../CoreGrid/doc/setup/ThunderID.md) and
[`CoreGrid/doc/SRS/appendix-c-thunderid-configuration-checklist.md`](../../../CoreGrid/doc/SRS/appendix-c-thunderid-configuration-checklist.md).
This file covers only what's specific to the Flutter client (checklist item 4). For running ThunderID, the
backend, and this app together against an emulator/device on your own machine — networking, TLS trust for
both self-signed dev certs, and the `flutter run` command — see
[`local-dev-networking.md`](local-dev-networking.md).

## Registration

Register CoreGrid Mobile in ThunderID as a **mobile / native application** (public client — no secret):

- **Sign-In Approach: Redirect / hosted login — not "Bring Your Own UI".** ThunderID's console offers both
  for a Flutter application type; BYOUI has the app call `/flow/execute`, `/flow/meta` and the
  `/register/passkey/*` endpoints directly to render its own native login screen, which means credentials
  never pass through an external user agent. That's exactly the anti-pattern RFC 8252 exists to steer public
  clients away from, and it directly conflicts with SEC-ID-06 (SRS §4.9, Must-priority: "the Flutter client
  shall use an external user agent for authentication"). It would also mean hand-rolling the flow-driving
  state machine and native passkey ceremonies (Android Credential Manager / iOS
  `ASAuthorizationController`) instead of using `flutter_appauth`, and would diverge from the React SPA's
  own redirect-based hosted login (`CoreGrid/doc/setup/ThunderID.md` step 4). If the console currently has
  this application set to Bring Your Own UI, switch it to the redirect-based sign-in approach before
  building against it.
- **Grant type:** Authorisation Code with PKCE
- **User agent:** external (system browser / Custom Tabs), never an embedded WebView — required by
  RFC 8252 and SRS SEC-ID-06, so the user can see ThunderID's own address bar during sign-in. With the
  redirect approach, the app never calls `/flow/execute`/`/flow/meta` itself — ThunderID's own hosted page,
  opened in the external user agent, does that internally.
- **Redirect URI:** a custom URL scheme unique to this app (e.g. `com.coregrid.mobile://auth-callback`) —
  not an `https://` deep link, unless ThunderID's mobile client type in your deployment specifically expects
  App Links/Universal Links instead
- **Allowed user type:** `CoreGridUser` only (same type as the React SPA — see
  `CoreGrid/doc/setup/ThunderID.md` step 1). Leave "Allow all user types" off.
- **Access token attributes:** `email`, `given_name`, `family_name`, `roles` — the same set as the React SPA
  (`CoreGrid/docs/setup/thunderid.md` step 4). **Scopes:** `openid`, `profile`, `email`, `roles` (the app
  requests all four). The backend's `RoleEnrichmentMiddleware` resolves each bearer token to a CoreGrid user
  by `sub`, and first-time-provisions one only when all four claims are present; otherwise every call —
  `GET /api/me` included — returns 401, and the dashboard reports "CoreGrid rejected your sign-in (401)".
  The signed-in user must also have a CoreGrid role (`Staff` or `InventoryOfficer`) assigned in ThunderID.
- **Token lifetimes:** inherited from the deployment-wide configuration (access token 15 min, refresh token
  rotation enabled) — nothing mobile-specific to set here

## Claim contract check

The access token's claim set was verified against the SRS §4.4 contract on 2026-08-18 and matches: `iss`,
`exp`/`nbf`/`iat`, `sub`, `roles`, `email`, `given_name`, `family_name`, `scope`, `jti` are all present. The
token also carries `aud`, `client_id`, `grant_type` and `username`, which are extra and harmless — the API
doesn't validate `aud` (SRS §4.4) and doesn't depend on the others.

## Recording the result

Record the following in your local, **untracked** environment config — never commit them:

- Application ID (the console's own identifier — **confirm this is also the OAuth `client_id`**; on the web
  app registration it is not — `ThunderID.md`'s troubleshooting table notes `VITE_THUNDERID_CLIENT_ID` must
  be the Client ID, not the Application ID, and `invalid_client` is the symptom of mixing them up)
- Redirect URI / custom scheme
- ThunderID issuer URL (discovery document endpoint)

## Token storage rule

Refresh tokens go in `flutter_secure_storage` (Android Keystore-backed). Access tokens stay in memory only.
Never write either to shared preferences, plain files, or application logs (SEC-ID-05, SEC-ID-06, SRS §4.8).

## Troubleshooting: browser signs in but the app never comes back

Symptom: ThunderID's login completes in Custom Tabs, the redirect fires, but the app stays on "Signing In…"
(or opens a blank instance) and logcat shows `W/AppAuth: No stored state - unable to handle response`.

Cause: `android:taskAffinity=""` on `MainActivity` (the Flutter template default). It puts the app in a
different task from AppAuth's `AuthorizationManagementActivity`, so the redirect is delivered to a fresh
instance that has no record of the pending request. `android/app/src/main/AndroidManifest.xml` deliberately
omits the attribute — don't re-add it. (flutter_appauth README, "No Redirect to app after login".)
