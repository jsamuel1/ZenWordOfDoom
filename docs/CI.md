# CI / CD

Two GitHub Actions workflows live in [`.github/workflows`](../.github/workflows).

The Xcode project is **not committed** — it is generated from
[`project.yml`](../project.yml) by [XcodeGen](https://github.com/yonaskolb/XcodeGen)
in CI (and locally). This keeps a readable, mergeable project definition and
avoids `.pbxproj` conflicts.

```sh
# Local setup
brew install xcodegen
xcodegen generate            # creates ZenWordOfDoom.xcodeproj
open ZenWordOfDoom.xcodeproj
# or run the logic tests with no Xcode project at all:
swift test
```

## `ci.yml` — Build & test
Runs on every push and pull request.

- **swift-packages** — `swift test` over the pure-Swift cores
  (`GameCore`, `WordEngine`). Fast, no simulator.
- **ios-app** — `xcodegen generate` then `xcodebuild build` for the app on an
  iPhone simulator (compiles + links the SwiftUI shell against the package).
  Code signing is disabled for this build.

## `release.yml` — Build & publish
Triggered by pushing a version tag `vX.Y.Z`, or manually (choose `testflight`
or `appstore`). It generates the project, archives, exports a signed `.ipa`,
and uploads to App Store Connect / TestFlight.

It **self-skips** (with a warning, exit 0) if the signing secret below is
absent — so tagging is safe before credentials are set up.

## Required credentials

The workflow uses **automatic (cloud) code signing** via an App Store Connect
API key. Xcode fetches/generates the distribution certificate and provisioning
profile on the fly, so there is **no `.p12`, `.mobileprovision`, or keychain**
to manage — just one secret plus a few non-sensitive identifiers.

Configure under **Settings → Secrets and variables → Actions**.

### Secret (sensitive — the only one)

| Name | What it is | Where to get it |
| --- | --- | --- |
| `APP_STORE_CONNECT_KEY_P8` | Full contents of the downloaded `AuthKey_XXXX.p8` | Downloaded **once** when you create the key (paste the whole text, `-----BEGIN…` to `…END-----`). If lost, generate a new key. |

> The private key (`.p8`) is the sensitive part — only ever paste it into this
> secret, never into a file, commit, issue, or chat. The two ids below are not
> secret, but keep them as **Variables** rather than committing them to a
> public repo.

### Variables (non-sensitive identifiers)

| Name | Example | Where to get it |
| --- | --- | --- |
| `APP_STORE_CONNECT_KEY_ID` | `YH4RWCPJB6` | App Store Connect → Users and Access → Integrations → App Store Connect API (the key's row) |
| `APP_STORE_CONNECT_ISSUER_ID` | `69a6de96-…` (UUID) | Same page, shown above the keys table |
| `APPLE_TEAM_ID` | `AB12CD34EF` | Apple Developer → Membership |
| `APP_BUNDLE_ID` | `com.yourco.zenwordofdoom` | Must match the app record + `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` |
| `APP_SCHEME` | `ZenWordOfDoom` (default) | Xcode scheme (optional) |
| `XCODE_VERSION` | pinned in workflow | Toolchain override (optional) |

### One-time Apple setup checklist
1. Enroll in the Apple Developer Program ($99/yr) — required to upload builds.
2. Register the **bundle id** (`APP_BUNDLE_ID`) in the Developer portal and
   create the app record in App Store Connect.
3. Create an **App Store Connect API key** with the **App Manager** role
   (Users and Access → Integrations). Save the `.p8`.
4. Update `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` to your bundle id.
5. Add the secret + variables above. Push a tag `v0.1.0` to publish.

> The API key role must be **App Manager** (or Admin) so it can manage signing
> assets for `-allowProvisioningUpdates`. Until step 5 is done, `release.yml`
> no-ops safely and `ci.yml` still builds and tests every push.
