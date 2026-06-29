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

It **self-skips** (with a warning, exit 0) if the signing/App Store Connect
secrets below are absent — so tagging is safe before credentials are set up.

## Xcode Cloud
Xcode Cloud is wired to the repo via the GitHub app and can build/publish as an
alternative to `release.yml`. Because the `.xcodeproj` is **not committed**,
[`ci_scripts/ci_post_clone.sh`](../ci_scripts/ci_post_clone.sh) runs right after
Xcode Cloud clones the repo — it installs XcodeGen and runs `xcodegen generate`
so the project exists before the build starts. Configure the workflow (triggers,
TestFlight/App Store distribution, signing) in App Store Connect → Xcode Cloud.

## Runner / toolchain
Both workflows run on the **`macos-26`** runner pinned to **Xcode 26.5**
(`XCODE_VERSION`), whose iOS 26.5 SDK is the newest available on GitHub-hosted
runners. The app's deployment target (`project.yml`) is kept at **iOS 26.5** to
match — bumping one means bumping the other.

## Required credentials

Configure under **Settings → Secrets and variables → Actions**.

### Secrets (sensitive)

| Name | What it is | Where to get it |
| --- | --- | --- |
| `APP_STORE_CONNECT_KEY_ID` | API key ID (e.g. `2X9R4HXF34`) | App Store Connect → Users and Access → Integrations → App Store Connect API → generate a key |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID (UUID) | Same page, shown above the keys table |
| `APP_STORE_CONNECT_KEY_P8` | Full contents of the downloaded `AuthKey_XXXX.p8` | Downloaded once when you create the key (paste the whole text, `-----BEGIN…` to `…END-----`) |
| `BUILD_CERTIFICATE_BASE64` | base64 of your **Apple Distribution** certificate `.p12` | Export the cert+key from Keychain Access as `.p12`, then `base64 -i dist.p12 \| pbcopy` |
| `P12_PASSWORD` | Password you set when exporting the `.p12` | You choose it at export time |
| `PROVISIONING_PROFILE_BASE64` | base64 of the App Store `.mobileprovision` | Apple Developer → Profiles → create an App Store profile for the bundle id, then `base64 -i profile.mobileprovision \| pbcopy` |
| `APPLE_TEAM_ID` | 10-char Team ID (e.g. `AB12CD34EF`) | Apple Developer → Membership |
| `KEYCHAIN_PASSWORD` | Any throwaway string | Invent one; only used to unlock the ephemeral CI keychain |

### Variables (non-sensitive)

| Name | Default | Purpose |
| --- | --- | --- |
| `APP_BUNDLE_ID` | — | e.g. `com.yourcompany.zenwordofdoom` (must match `project.yml` + the profile) |
| `PROVISIONING_PROFILE_NAME` | — | The profile's **name** as shown in the Developer portal |
| `APP_SCHEME` | `ZenWordOfDoom` | Xcode scheme |
| `XCODE_VERSION` | pinned in workflow | Toolchain override |

### One-time Apple setup checklist
1. Enroll in the Apple Developer Program ($99/yr) — required to upload builds.
2. Register the **bundle id** (`APP_BUNDLE_ID`) in the Developer portal and
   create the app record in App Store Connect.
3. Create an **Apple Distribution** certificate; export it as `.p12`.
4. Create an **App Store** provisioning profile for that bundle id.
5. Create an **App Store Connect API key** (Admin or App Manager role).
6. Update `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` to your bundle id.
7. Add the secrets/variables above. Push a tag `v0.1.0` to publish.

> Until step 7 is done, `release.yml` no-ops safely and `ci.yml` still builds
> and tests every push.
