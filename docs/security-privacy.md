# Security & Privacy

## Credentials

- Tokens in Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- Optional Face ID / Touch ID gate on app launch (Settings → Security → Require biometrics).
- Token re-validated on app launch and on every 401; expired token → forced re-login.
- Custom CAs stored alongside the deployment record in Keychain.

## Network

- ATS configured to require TLS 1.2+ everywhere.
- Per-host exception list editable for self-hosted HTTP / dev environments (rare; warn user).
- Optional certificate pinning for paranoid deployments (configurable per deployment).

## Pasteboard

- Items typed by user from clipboard expire from system clipboard after 60s by default (configurable).
- Implemented via `UIPasteboard` expiration.

## Screen privacy

- Optional screen-recording detection (`UIScreen.isCaptured`) → blur terminal.
- App switcher snapshot replaced with logo (`applicationDidEnterBackground` swap).
- Optional: hide previous-session terminal contents on app re-foreground until biometric unlock.

## Telemetry

**Zero telemetry by default.** This is a selling point in the App Store description.

- No analytics SDKs.
- Optional opt-in crash reporting via Sentry self-hosted endpoint (user supplies the DSN in Settings → Diagnostics).
- All logs are local; user can export via Settings → Diagnostics → Export logs (writes to share sheet).
- Logger redacts: tokens, OIDC codes, full URLs (host only), PTY content (never logged).

## App Store compliance

- Privacy Manifest (`PrivacyInfo.xcprivacy`) declares: no tracking, no data collection beyond what user enters.
- Privacy policy hosted at `coderterminal.app/privacy`, linked from Settings and App Store listing.
- Required reason API declarations: Keychain, file-timestamp, user-defaults (all standard).

## Threat model

| Threat | Mitigation |
|---|---|
| Stolen device | Biometric gate + Keychain `AfterFirstUnlockThisDeviceOnly` |
| Shoulder-surfing | Optional terminal blur on `UIScreen.isCaptured`; pasteboard expiry |
| Network MITM on self-hosted | Optional cert pinning per deployment; user-managed CA trust |
| Token leak via logs | Redacting log formatter; PTY bytes never logged |
| Malicious OIDC redirect | PKCE + custom URL scheme verification |
| App backgrounded with sensitive output on screen | App-switcher snapshot replacement |
