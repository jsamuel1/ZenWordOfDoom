# CI / CD

Two GitHub Actions workflows live in [`.github/workflows`](../.github/workflows).

## `ci.yml` — Build & test
Runs on every push and pull request (and manually).

- **swift-packages** — `swift test` for every `Package.swift` (the pure-Swift
  cores: `GameCore`, `WordEngine`, …).
- **ios-app** — `xcodebuild clean test` on an iPhone simulator.

Both jobs are **spec-phase tolerant**: if no `Package.swift` /
`.xcodeproj` / `.xcworkspace` exists yet, the job logs a notice and succeeds
instead of failing. They activate automatically once those files land.

## `release.yml` — Build & publish
Triggered by pushing a version tag `vX.Y.Z`, or manually (choose `testflight`
or `appstore`). It archives the app, exports a signed `.ipa`, and uploads it to
App Store Connect / TestFlight. Dormant (no-op) until an Xcode project exists.

### Required secrets & variables
Configure under **Settings → Secrets and variables → Actions**:

| Type | Name | Purpose |
| --- | --- | --- |
| Secret | `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key id |
| Secret | `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect issuer id |
| Secret | `APP_STORE_CONNECT_KEY_P8` | Contents of the `.p8` private key |
| Secret | `BUILD_CERTIFICATE_BASE64` | base64 of the distribution `.p12` |
| Secret | `P12_PASSWORD` | password for the `.p12` |
| Secret | `PROVISIONING_PROFILE_BASE64` | base64 of the `.mobileprovision` |
| Secret | `KEYCHAIN_PASSWORD` | any ephemeral keychain password |
| Variable | `APP_SCHEME` | Xcode scheme (default `ZenWordOfDoom`) |
| Variable | `APP_BUNDLE_ID` | e.g. `com.example.zenwordofdoom` |
| Variable | `XCODE_VERSION` (optional) | toolchain override |

> To produce the base64 inputs locally:
> `base64 -i dist.p12 | pbcopy` and `base64 -i profile.mobileprovision | pbcopy`.

The toolchain version is pinned via `XCODE_VERSION` in each workflow; bump it as
new Xcode releases land on the `macos-14` runner image.
