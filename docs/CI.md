# CI / CD

Build and test run on **GitHub Actions** ([`.github/workflows/ci.yml`](../.github/workflows/ci.yml)).
Archiving and publishing to TestFlight / the App Store are handled by
**Xcode Cloud** (see below).

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

Runs on the **`macos-26`** runner pinned to **Xcode 26.5** (`XCODE_VERSION`),
whose iOS 26.5 SDK is the newest available on GitHub-hosted runners. The app's
deployment target (`project.yml`) is kept at **iOS 26.5** to match — bumping one
means bumping the other.

Optional repo **Variables** (Settings → Secrets and variables → Actions):

| Name | Default | Purpose |
| --- | --- | --- |
| `APP_SCHEME` | `ZenWordOfDoom` | Xcode scheme to build |
| `XCODE_VERSION` | pinned in workflow | Toolchain override |

No signing secrets are needed: `ci.yml` never signs, and Xcode Cloud manages
signing for releases.

## Publishing — Xcode Cloud
Xcode Cloud (wired to the repo via the GitHub app) archives and uploads builds,
managing signing certificates and provisioning profiles automatically — so no
distribution certs or App Store Connect API keys live in the repo.

Because the `.xcodeproj` is **not committed**,
[`ci_scripts/ci_post_clone.sh`](../ci_scripts/ci_post_clone.sh) runs right after
Xcode Cloud clones the repo: it installs XcodeGen and runs `xcodegen generate`
so the project exists before the build starts.

The workflow itself (triggers, archive action, TestFlight / App Store
distribution) is configured in **App Store Connect → Xcode Cloud**, not in the
repo. Typical setup:

1. In Xcode (or App Store Connect), create an Xcode Cloud workflow for the
   **ZenWordOfDoom** scheme and grant Xcode Cloud access to the team.
2. Choose a **Start Condition** — e.g. a new tag `v*.*.*`, or pushes to `main`.
3. Add an **Archive** action (Release) and a **TestFlight (Internal)** (or
   App Store) post-action.
4. Ensure the bundle id `wtf.sauhsoj.zenwordofdoom` has an app record in
   App Store Connect; Xcode Cloud handles signing from there.

### Version & build numbers
`MARKETING_VERSION` (`0.1.0`) and `CURRENT_PROJECT_VERSION` (`1`) come from
`project.yml`. TestFlight requires the **build number** to increase on each
upload — let Xcode Cloud auto-increment it, or bump `CURRENT_PROJECT_VERSION`
in `project.yml` per release.
