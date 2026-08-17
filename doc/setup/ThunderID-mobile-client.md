# ThunderID — Mobile Client Registration

The web application's ThunderID setup is documented in
[`CoreGrid/doc/setup/ThunderID.md`](../../../CoreGrid/doc/setup/ThunderID.md) and
[`CoreGrid/doc/SRS/appendix-c-thunderid-configuration-checklist.md`](../../../CoreGrid/doc/SRS/appendix-c-thunderid-configuration-checklist.md).
This file covers only what's specific to the Flutter client (checklist item 4).

## Registration

Register CoreGrid Mobile in ThunderID as a **mobile / native application** (public client — no secret):

- **Grant type:** Authorisation Code with PKCE
- **User agent:** external (system browser / Custom Tabs), never an embedded WebView — required by
  RFC 8252 and SRS SEC-ID-06, so the user can see ThunderID's own address bar during sign-in
- **Redirect URI:** a custom URL scheme unique to this app (e.g. `com.coregrid.mobile://auth-callback`) —
  not an `https://` deep link, unless ThunderID's mobile client type in your deployment specifically expects
  App Links/Universal Links instead
- **Token lifetimes:** inherited from the deployment-wide configuration (access token 15 min, refresh token
  rotation enabled) — nothing mobile-specific to set here

## Recording the result

Record the following in your local, **untracked** environment config — never commit them:

- Client ID
- Redirect URI / custom scheme
- ThunderID issuer URL (discovery document endpoint)

## Token storage rule

Refresh tokens go in `flutter_secure_storage` (Android Keystore-backed). Access tokens stay in memory only.
Never write either to shared preferences, plain files, or application logs (SEC-ID-05, SEC-ID-06, SRS §4.8).
