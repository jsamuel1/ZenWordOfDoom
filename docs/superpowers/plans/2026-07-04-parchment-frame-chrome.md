# Parchment/Oriental-Frame Chrome Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reskin the app's recurring button/pill chrome (Play, Submit, HUD pills, word ribbon, etc.) with generated aged-parchment/oriental-frame textures, per-theme (Zen/Doom), stretchable via 9-slice `capInsets` so Dynamic Type keeps working, with a code-enforced contrast scrim so legibility is WCAG-AA regardless of the generated art.

**Architecture:** Two new SwiftUI primitives (`ParchmentButtonStyle`, `.parchmentReadout(theme:)`) in a new `ParchmentChrome.swift`, backed by 6 generated PNG textures (3 shapes × 2 themes) in a new `Frames/` asset-catalog group, wired into 6 existing view files in place of their current `.buttonStyle(.bordered/.borderedProminent)` / `.a11yCardBackground` chrome.

**Tech Stack:** SwiftUI (`Image.resizable(capInsets:resizingMode:)`, custom `ButtonStyle`), the `agy` CLI for offline PNG generation (existing project convention, see `scripts/generate-daily-word-images.sh`), XCTest for pinned-contrast and asset-existence tests.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-04-parchment-frame-chrome-design.md` — read it before starting; this plan implements it exactly, with one factual correction noted in Task 9 (FoundWordsTray's actual chrome is per-bonus-word tags, not a single "progress pill" as the spec's prose loosely says — the intent, "reskin the tray's existing translucent-card chrome," is unchanged).
- **Out of scope, do not touch:** `LevelSelectView` rows, `SettingsView`, `LevelClearView`'s card/Continue button, `SerenitySheetView`, `DoomExpiredOverlay`, `PackBannerView`, and MenuView's Serenity-count button (only Play/Select Level/Bestiary/Shrine/Stats/Settings/"Today's Doom" are in scope there).
- `a11yCardBackground` (`App/ZenWordOfDoom/A11yCardBackground.swift`) must not be modified — it's shared by out-of-scope call sites.
- Every new button/readout must keep its existing 44×44pt minimum touch target and existing `accessibilityLabel`/`accessibilityHint` — this is a visual-chrome-only change, not an accessibility-behavior change.
- Contrast pairs are fixed constants pinned by a unit test (`WCAGContrastTests`), never sampled from the generated image at runtime.
- Follow existing project conventions: `Theme` is passed as an explicit parameter (no `EnvironmentKey` exists for it), asset generation uses the `agy` CLI via a `set -eu` shell script mirroring `scripts/generate-daily-word-images.sh`.
- Run `xcodegen generate` after adding new files/assets, before building, per this project's standard workflow (the `.xcodeproj` is gitignored/generated).
- Test runner: App-target tests (`ZenWordOfDoomTests`) run via `xcodebuild test -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=<a booted sim>' -only-testing:ZenWordOfDoomTests/<ClassName>`. Package tests (`Sources/**`) run via `swift test` — not used in this plan since nothing here touches `Sources/`.

---

## Task 1: Parchment contrast constants + pinned test

**Files:**
- Modify: `App/ZenWordOfDoom/AccessibilityPalette.swift`
- Modify: `App/ZenWordOfDoomTests/WCAGContrastTests.swift`

**Interfaces:**
- Produces: `AccessibilityPalette.parchmentInk(for theme: Theme) -> Color`, `AccessibilityPalette.parchmentScrim(for theme: Theme) -> Color`, and the underlying constants `parchmentInkZen`/`parchmentInkDoom`/`parchmentScrimZen`/`parchmentScrimDoom`. Every later task that draws parchment chrome calls `parchmentInk(for:)`/`parchmentScrim(for:)` — never the raw constants directly, so the theme branch lives in exactly one place.

- [ ] **Step 1: Write the failing test**

In `App/ZenWordOfDoomTests/WCAGContrastTests.swift`, insert a new test method right after `testGridPairsMeetAA()` (which currently ends at line 24 with a lone `}`), before `testKnownRatioSanity()`:

```swift
    func testParchmentPairsMeetAA() {
        XCTAssertGreaterThanOrEqual(ratio(AccessibilityPalette.parchmentInkZen,
                                          AccessibilityPalette.parchmentScrimZen), 4.5)
        XCTAssertGreaterThanOrEqual(ratio(AccessibilityPalette.parchmentInkDoom,
                                          AccessibilityPalette.parchmentScrimDoom), 4.5)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodegen generate && xcodebuild test -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ZenWordOfDoomTests/WCAGContrastTests`
Expected: **BUILD FAILED** — `AccessibilityPalette.parchmentInkZen`/etc. don't exist yet (compile error, not a runtime test failure — that's fine, it proves the test references something real work must create).

- [ ] **Step 3: Add the constants and helpers**

In `App/ZenWordOfDoom/AccessibilityPalette.swift`, change the import block at the top (currently lines 1-2):

```swift
import SwiftUI
import UIKit
import LevelGen
```

Then insert this new section right before the existing `// MARK: - WCAG math` comment (currently line 44, immediately after `gridCellStrokeIncreased`'s declaration and a blank line):

```swift
    // MARK: - Parchment chrome (frame textures + scrim, see ParchmentChrome.swift)

    static let parchmentScrimZen = Color(.sRGB, red: 0.95, green: 0.90, blue: 0.78, opacity: 0.9)
    static let parchmentInkZen = Color(.sRGB, red: 0.16, green: 0.11, blue: 0.07, opacity: 1)
    static let parchmentScrimDoom = Color(.sRGB, red: 0.14, green: 0.10, blue: 0.08, opacity: 0.9)
    static let parchmentInkDoom = Color(.sRGB, red: 0.93, green: 0.84, blue: 0.64, opacity: 1)

    /// Text/icon color to draw over parchment chrome for the given theme —
    /// always paired with `parchmentScrim(for:)`, never the raw texture.
    static func parchmentInk(for theme: Theme) -> Color {
        theme == .doom ? parchmentInkDoom : parchmentInkZen
    }

    /// Scrim color composited between the parchment texture and its content
    /// (text/icons), so contrast stays WCAG-AA regardless of the generated
    /// texture's exact pixels. See `ParchmentChrome.swift`.
    static func parchmentScrim(for theme: Theme) -> Color {
        theme == .doom ? parchmentScrimDoom : parchmentScrimZen
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ZenWordOfDoomTests/WCAGContrastTests`
Expected: **TEST SUCCEEDED**, all `WCAGContrastTests` methods pass including `testParchmentPairsMeetAA`.

If it fails on the ratio assertion (not a compile error), the chosen RGB values don't clear 4.5:1 — nudge `parchmentInkZen` darker or `parchmentScrimZen` lighter (same relationship, opposite direction for Doom) and re-run until it passes. Do not lower the `4.5` threshold.

- [ ] **Step 5: Commit**

```bash
git add App/ZenWordOfDoom/AccessibilityPalette.swift App/ZenWordOfDoomTests/WCAGContrastTests.swift
git commit -m "feat(app): add pinned parchment-chrome contrast constants"
```

---

## Task 2: `ParchmentShape` — asset naming + capInsets

**Files:**
- Create: `App/ZenWordOfDoom/ParchmentChrome.swift`
- Create: `App/ZenWordOfDoomTests/ParchmentChromeTests.swift`

**Interfaces:**
- Consumes: nothing new (only `LevelGen.Theme`, already in the codebase).
- Produces: `enum ParchmentShape { case wide, icon, strip }` with `static func assetName(theme: Theme, shape: ParchmentShape) -> String` and `var capInsets: EdgeInsets`. Task 3 (asset generation) uses `assetName` to name the files it generates. Tasks 4-5 (`ParchmentButtonStyle`, `.parchmentReadout`) use both.

- [ ] **Step 1: Write the failing test**

Create `App/ZenWordOfDoomTests/ParchmentChromeTests.swift`:

```swift
import XCTest
import LevelGen
@testable import ZenWordOfDoom

final class ParchmentChromeTests: XCTestCase {
    func testAssetNameMapping() {
        XCTAssertEqual(ParchmentShape.assetName(theme: .zen, shape: .wide), "frame-zen-button")
        XCTAssertEqual(ParchmentShape.assetName(theme: .doom, shape: .wide), "frame-doom-button")
        XCTAssertEqual(ParchmentShape.assetName(theme: .zen, shape: .icon), "frame-zen-icon")
        XCTAssertEqual(ParchmentShape.assetName(theme: .doom, shape: .icon), "frame-doom-icon")
        XCTAssertEqual(ParchmentShape.assetName(theme: .zen, shape: .strip), "frame-zen-strip")
        XCTAssertEqual(ParchmentShape.assetName(theme: .doom, shape: .strip), "frame-doom-strip")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodegen generate && xcodebuild test -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ZenWordOfDoomTests/ParchmentChromeTests`
Expected: **BUILD FAILED** — `ParchmentShape` doesn't exist yet.

- [ ] **Step 3: Create `ParchmentChrome.swift` with the shape enum**

Create `App/ZenWordOfDoom/ParchmentChrome.swift`:

```swift
import SwiftUI
import LevelGen

/// The three parchment-frame texture shapes generated for this app's chrome
/// (see `docs/superpowers/specs/2026-07-04-parchment-frame-chrome-design.md`).
/// `.wide` and `.icon` back `ParchmentButtonStyle`; `.strip` backs
/// `.parchmentReadout(theme:)`. Textures live in `Assets.xcassets/Frames/`.
enum ParchmentShape {
    case wide
    case icon
    case strip

    /// Fixed border margin (in the texture's own point space) that must not
    /// stretch — the torn-edge/corner-ornament detail lives here. Only the
    /// region inside these insets stretches when the view resizes.
    var capInsets: EdgeInsets {
        switch self {
        case .wide: EdgeInsets(top: 70, leading: 110, bottom: 70, trailing: 110)
        case .icon: EdgeInsets(top: 90, leading: 90, bottom: 90, trailing: 90)
        case .strip: EdgeInsets(top: 35, leading: 100, bottom: 35, trailing: 100)
        }
    }

    static func assetName(theme: Theme, shape: ParchmentShape) -> String {
        let themeName = theme == .doom ? "doom" : "zen"
        let shapeName: String
        switch shape {
        case .wide: shapeName = "button"
        case .icon: shapeName = "icon"
        case .strip: shapeName = "strip"
        }
        return "frame-\(themeName)-\(shapeName)"
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ZenWordOfDoomTests/ParchmentChromeTests`
Expected: **TEST SUCCEEDED**.

- [ ] **Step 5: Commit**

```bash
git add App/ZenWordOfDoom/ParchmentChrome.swift App/ZenWordOfDoomTests/ParchmentChromeTests.swift
git commit -m "feat(app): add ParchmentShape asset-name/capInsets mapping"
```

---

## Task 3: Generate the 6 frame textures via `agy`

**Files:**
- Create: `scripts/generate-parchment-frames.sh`
- Create (generated by the script, not by hand): `App/ZenWordOfDoom/Assets.xcassets/Frames/frame-{zen,doom}-{button,icon,strip}.imageset/` (6 folders, each with a PNG + `Contents.json`)
- Modify: `App/ZenWordOfDoomTests/ParchmentChromeTests.swift`

**Interfaces:**
- Consumes: `ParchmentShape.assetName(theme:shape:)` (Task 2) — the script's imageset folder/file names must exactly match what that function returns, since Task 4/5 look images up by that name.
- Produces: 6 bundled image assets that `Image("frame-...")` can load by name.

- [ ] **Step 1: Write the failing test**

In `App/ZenWordOfDoomTests/ParchmentChromeTests.swift`, add (needs `UIKit` for `UIImage`):

```swift
import UIKit
```

at the top (alongside the existing `import XCTest` / `import LevelGen` / `@testable import ZenWordOfDoom`), and add this test method inside the class:

```swift
    func testAllFrameTexturesExistInBundle() {
        for theme in [Theme.zen, Theme.doom] {
            for shape in [ParchmentShape.wide, .icon, .strip] {
                let name = ParchmentShape.assetName(theme: theme, shape: shape)
                XCTAssertNotNil(UIImage(named: name), "missing bundled asset \(name)")
            }
        }
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ZenWordOfDoomTests/ParchmentChromeTests/testAllFrameTexturesExistInBundle`
Expected: **TEST FAILED** — all 6 `XCTAssertNotNil` fail, no `frame-*` assets exist yet.

- [ ] **Step 3: Write the generation script**

Create `scripts/generate-parchment-frames.sh` (mirrors `scripts/generate-daily-word-images.sh`'s structure exactly — idempotent, retries, paced):

```sh
#!/bin/sh
# Generates the 6 parchment/oriental-frame chrome textures (3 shapes x 2
# themes) via the `agy` (Antigravity) CLI and installs each into
# Assets.xcassets/Frames/, following the existing bundled-visuals convention
# (frame-<theme>-<shape>.imageset/frame-<theme>-<shape>.png + Contents.json).
# Idempotent: re-running skips any texture that already has a bundled image.
# Paced with a delay between calls since `agy` has usage limits.
#
# Texture design (see docs/superpowers/specs/2026-07-04-parchment-frame-chrome-design.md
# section 4-5): each PNG has a transparent margin outside its torn silhouette,
# a richly-detailed torn-edge/corner-ornament border, and a near-solid,
# low-variance center panel toned to blend with the matching code-drawn scrim
# (ParchmentChrome.swift / AccessibilityPalette.parchmentScrim(for:)) rather
# than fighting it.
set -eu

cd "$(dirname "$0")/.."
ASSETS_DIR="App/ZenWordOfDoom/Assets.xcassets/Frames"
DELAY_SECONDS=15
MAX_RETRIES=3

# name|size|prompt — one line per texture.
TEXTURES='
frame-zen-button|900x300|A wide rectangular aged parchment texture with softly torn deckled edges and a delicate oriental ink-line corner ornament in each corner, warm tea-stained cream color, the center two-thirds a smooth near-solid muted warm cream tone designed to blend under a matching semi-transparent cream overlay, isolated on a transparent background, no text, alpha transparency outside the torn paper silhouette, restrained and calm illustration style
frame-zen-icon|320x320|A small square aged parchment medallion with torn deckled edges all around and a delicate oriental ink-line ornament framing the border, warm tea-stained cream color, the center a smooth near-solid muted warm cream tone designed to blend under a matching semi-transparent cream overlay, isolated on a transparent background, no text, alpha transparency outside the torn paper silhouette, restrained and calm illustration style
frame-zen-strip|900x160|A thin horizontal banner strip of aged parchment with torn deckled edges on the short ends and a delicate oriental ink-line ornament at each end, warm tea-stained cream color, the center a smooth near-solid muted warm cream tone designed to blend under a matching semi-transparent cream overlay, isolated on a transparent background, no text, alpha transparency outside the torn paper silhouette, restrained and calm illustration style
frame-doom-button|900x300|A wide rectangular scorched and charred aged parchment texture with jagged burnt torn edges and a heavy blackened oriental corner ornament in each corner, dark charred brown color, the center two-thirds a smooth near-solid muted charred-brown tone designed to blend under a matching semi-transparent dark overlay, isolated on a transparent background, no text, alpha transparency outside the torn paper silhouette, ominous stylized illustration
frame-doom-icon|320x320|A small square scorched and charred aged parchment medallion with jagged burnt torn edges all around and a heavy blackened oriental ornament framing the border, dark charred brown color, the center a smooth near-solid muted charred-brown tone designed to blend under a matching semi-transparent dark overlay, isolated on a transparent background, no text, alpha transparency outside the torn paper silhouette, ominous stylized illustration
frame-doom-strip|900x160|A thin horizontal banner strip of scorched and charred aged parchment with jagged burnt torn edges on the short ends and a heavy blackened oriental ornament at each end, dark charred brown color, the center a smooth near-solid muted charred-brown tone designed to blend under a matching semi-transparent dark overlay, isolated on a transparent background, no text, alpha transparency outside the torn paper silhouette, ominous stylized illustration
'

echo "$TEXTURES" | while IFS='|' read -r name size prompt; do
  [ -z "$name" ] && continue
  imageset_dir="$ASSETS_DIR/$name.imageset"
  image_path="$imageset_dir/$name.png"

  if [ -s "$image_path" ] && [ -f "$imageset_dir/Contents.json" ]; then
    echo "skip $name (already generated)"
    continue
  fi

  mkdir -p "$imageset_dir"
  attempt=1
  while [ "$attempt" -le "$MAX_RETRIES" ]; do
    echo "generating $name ($size, attempt $attempt/$MAX_RETRIES)..."
    if agy -p "Generate a $size pixel PNG image with alpha transparency for this description and save it to $PWD/$image_path: $prompt" --dangerously-skip-permissions < /dev/null; then
      if [ -s "$image_path" ]; then
        break
      fi
    fi
    echo "  retry after throttle/failure..."
    attempt=$((attempt + 1))
    sleep "$DELAY_SECONDS"
  done

  if [ ! -s "$image_path" ]; then
    echo "FAILED to generate $name after $MAX_RETRIES attempts — re-run this script later to retry" >&2
    exit 1
  fi

  cat > "$imageset_dir/Contents.json" << EOF
{
  "images" : [
    {
      "filename" : "$name.png",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

  echo "done $name"
  sleep "$DELAY_SECONDS"
done

echo "All 6 parchment-frame textures generated."
```

Make it executable:

```bash
chmod +x scripts/generate-parchment-frames.sh
```

- [ ] **Step 4: Run the script to generate the real assets**

Run: `./scripts/generate-parchment-frames.sh`
Expected: after it completes (may take several minutes with retries/pacing), `App/ZenWordOfDoom/Assets.xcassets/Frames/` contains 6 `.imageset` folders, each with a non-empty PNG and a `Contents.json`.

Then **visually inspect each PNG** (e.g. `open App/ZenWordOfDoom/Assets.xcassets/Frames/frame-zen-button.imageset/frame-zen-button.png`, repeat for all 6). For each one, check where the richly-detailed torn/ornamented border actually ends and the near-solid center begins. If that boundary is meaningfully thicker or thinner than the `capInsets` values set in Task 2 (70/110pt for `.wide`, 90pt for `.icon`, 35/100pt for `.strip`, all relative to the stated canvas size), adjust those exact `ParchmentShape.capInsets` values in `App/ZenWordOfDoom/ParchmentChrome.swift` to match what was actually generated — the numbers must describe the real image, not the other way around.

- [ ] **Step 5: Regenerate the Xcode project and run the test**

Run: `xcodegen generate && xcodebuild test -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ZenWordOfDoomTests/ParchmentChromeTests`
Expected: **TEST SUCCEEDED** — `testAllFrameTexturesExistInBundle` now passes since the assets exist.

- [ ] **Step 6: Commit**

```bash
git add scripts/generate-parchment-frames.sh App/ZenWordOfDoom/Assets.xcassets/Frames App/ZenWordOfDoomTests/ParchmentChromeTests.swift App/ZenWordOfDoom/ParchmentChrome.swift
git commit -m "feat(app): generate the 6 parchment/oriental-frame chrome textures"
```

(The last file is included only if Step 4's visual check required a `capInsets` tweak; `git add` is a no-op for it otherwise.)

---

## Task 4: `ParchmentButtonStyle`

**Files:**
- Modify: `App/ZenWordOfDoom/ParchmentChrome.swift`

**Interfaces:**
- Consumes: `ParchmentShape.assetName(theme:shape:)`/`.capInsets` (Task 2), `AccessibilityPalette.parchmentInk(for:)`/`.parchmentScrim(for:)` (Task 1), the 6 bundled textures (Task 3).
- Produces: `struct ParchmentButtonStyle: ButtonStyle { init(theme: Theme, shape: ParchmentShape) }`. Tasks 6-8 construct this directly as `.buttonStyle(ParchmentButtonStyle(theme:shape:))`.

- [ ] **Step 1: Write the failing check**

This is a pure-rendering SwiftUI type with no independently testable pure logic beyond what Task 2 already covers — consistent with how this codebase treats other visual composition types (e.g. `SceneRevealView`, no unit tests beyond the accessibility audits). Instead of a new XCTest, the "failing test" here is a `#Preview` that won't compile until the type exists:

Append to the bottom of `App/ZenWordOfDoom/ParchmentChrome.swift`:

```swift
#Preview("ParchmentButtonStyle") {
    VStack(spacing: 16) {
        Button("Play") {}
            .buttonStyle(ParchmentButtonStyle(theme: .zen, shape: .wide))
        Button("Play") {}
            .buttonStyle(ParchmentButtonStyle(theme: .doom, shape: .wide))
        HStack(spacing: 16) {
            Button {} label: { Image(systemName: "lightbulb.fill") }
                .buttonStyle(ParchmentButtonStyle(theme: .zen, shape: .icon))
            Button {} label: { Image(systemName: "lightbulb.fill") }
                .buttonStyle(ParchmentButtonStyle(theme: .doom, shape: .icon))
        }
        Button("Disabled") {}
            .buttonStyle(ParchmentButtonStyle(theme: .zen, shape: .wide))
            .disabled(true)
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
```

- [ ] **Step 2: Verify it fails to build**

Run: `xcodebuild build -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: **BUILD FAILED** — `ParchmentButtonStyle` doesn't exist yet.

- [ ] **Step 3: Implement `ParchmentButtonStyle`**

Insert into `App/ZenWordOfDoom/ParchmentChrome.swift`, after the `ParchmentShape` enum and before the `#Preview`:

```swift
/// Custom `ButtonStyle` rendering a stretchable parchment/oriental-frame
/// texture behind the button's label instead of the system `.bordered`/
/// `.borderedProminent` chrome. See
/// `docs/superpowers/specs/2026-07-04-parchment-frame-chrome-design.md`.
struct ParchmentButtonStyle: ButtonStyle {
    let theme: Theme
    /// Only `.wide` or `.icon` — `.strip` backs `.parchmentReadout(theme:)`
    /// (non-button chrome) instead.
    let shape: ParchmentShape

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let insets = shape.capInsets
        configuration.label
            .foregroundStyle(AccessibilityPalette.parchmentInk(for: theme))
            .padding(.horizontal, shape == .icon ? 8 : 16)
            .padding(.vertical, shape == .icon ? 8 : 10)
            .frame(minWidth: 44, minHeight: 44)
            .background(
                ZStack {
                    Image(ParchmentShape.assetName(theme: theme, shape: shape))
                        .resizable(capInsets: insets, resizingMode: .stretch)
                        .accessibilityHidden(true)
                    AccessibilityPalette.parchmentScrim(for: theme)
                        .clipShape(RoundedRectangle(cornerRadius: shape == .icon ? 18 : 12, style: .continuous))
                        .padding(insets)
                }
            )
            .brightness(configuration.isPressed ? -0.08 : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .saturation(isEnabled ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.6)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
```

- [ ] **Step 4: Verify it builds and the preview renders**

Run: `xcodebuild build -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: **BUILD SUCCEEDED**. Open `ParchmentChrome.swift` in Xcode and check the `"ParchmentButtonStyle"` canvas preview: two wide "Play" buttons (Zen cream, Doom charred) with visibly torn/ornamented edges and legible text, two icon buttons, and a visibly desaturated/faded disabled button.

- [ ] **Step 5: Commit**

```bash
git add App/ZenWordOfDoom/ParchmentChrome.swift
git commit -m "feat(app): add ParchmentButtonStyle"
```

---

## Task 5: `.parchmentReadout(theme:)` modifier

**Files:**
- Modify: `App/ZenWordOfDoom/ParchmentChrome.swift`

**Interfaces:**
- Consumes: same as Task 4, plus always uses `ParchmentShape.strip`.
- Produces: `extension View { func parchmentReadout(theme: Theme) -> some View }`. Tasks 8-9 call `.parchmentReadout(theme:)` in place of `.a11yCardBackground(cornerRadius: .infinity)`.

- [ ] **Step 1: Extend the preview (failing build)**

Add to the bottom of the `#Preview("ParchmentButtonStyle")` block's `VStack` (before its closing `}`, i.e. as new content inside that same `VStack(spacing: 16) { ... }`):

```swift
        HStack(spacing: 4) {
            Image(systemName: "star.fill").font(.caption)
            Text("320").font(.subheadline.weight(.bold))
        }
        .parchmentReadout(theme: .zen)
```

- [ ] **Step 2: Verify it fails to build**

Run: `xcodebuild build -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: **BUILD FAILED** — `parchmentReadout(theme:)` doesn't exist yet.

- [ ] **Step 3: Implement the modifier**

Insert into `App/ZenWordOfDoom/ParchmentChrome.swift`, after `ParchmentButtonStyle` and before the `#Preview`:

```swift
private struct ParchmentReadoutModifier: ViewModifier {
    let theme: Theme

    func body(content: Content) -> some View {
        let insets = ParchmentShape.strip.capInsets
        content
            .foregroundStyle(AccessibilityPalette.parchmentInk(for: theme))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    Image(ParchmentShape.assetName(theme: theme, shape: .strip))
                        .resizable(capInsets: insets, resizingMode: .stretch)
                        .accessibilityHidden(true)
                    AccessibilityPalette.parchmentScrim(for: theme)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(insets)
                }
            )
    }
}

extension View {
    /// Non-button parchment chrome (HUD pills, doom timer, word ribbon,
    /// found-words tags) — the readout equivalent of `ParchmentButtonStyle`.
    /// Stands in for `.a11yCardBackground(...)` only at these specific call
    /// sites; `a11yCardBackground` itself is untouched.
    func parchmentReadout(theme: Theme) -> some View {
        modifier(ParchmentReadoutModifier(theme: theme))
    }
}
```

- [ ] **Step 4: Verify it builds and the preview renders**

Run: `xcodebuild build -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: **BUILD SUCCEEDED**. The preview canvas now also shows a small "★ 320" readout pill with the Zen strip texture.

- [ ] **Step 5: Commit**

```bash
git add App/ZenWordOfDoom/ParchmentChrome.swift
git commit -m "feat(app): add parchmentReadout(theme:) view modifier"
```

---

## Task 6: Wire `MenuView`

**Files:**
- Modify: `App/ZenWordOfDoom/MenuView.swift`

**Interfaces:**
- Consumes: `ParchmentButtonStyle` (Task 4). MenuView has no single level `Theme` in scope (it's the home screen), so every button here uses a **fixed `.zen` theme** — same reasoning as the existing menu title using `BrandFont.zen` (see spec §6).

- [ ] **Step 1: Replace the 6 in-scope buttons' styles**

In `App/ZenWordOfDoom/MenuView.swift`, the Play/Select Level/Bestiary/Shrine/Stats/Settings buttons (currently lines 86-144) each end with `.buttonStyle(.borderedProminent)` or `.buttonStyle(.bordered)` followed by `.controlSize(.large)`. Replace each pair. For example, Play (currently lines 94-99):

```swift
                            } label: {
                                Label("Play", systemImage: "leaf.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
```

becomes:

```swift
                            } label: {
                                Label("Play", systemImage: "leaf.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ParchmentButtonStyle(theme: .zen, shape: .wide))
```

(`.controlSize(.large)` is a system-button-style-only modifier — drop it at each of the 6 sites since `ParchmentButtonStyle` already sizes itself via its own padding/frame.)

Apply the same substitution — `.buttonStyle(.bordered)` / `.buttonStyle(.borderedProminent)` + `.controlSize(.large)` → `.buttonStyle(ParchmentButtonStyle(theme: .zen, shape: .wide))` — to Select Level, Bestiary, Shrine, Stats, and Settings (currently lines 107-108, 116-117, 125-126, 134-135, 143-144 respectively).

- [ ] **Step 2: Replace `dailyCard`'s ("Today's Doom") inline chrome**

`dailyCard` (currently lines 185-224) builds its own background manually. Change:

```swift
            .padding(14)
            .a11yCardBackground(cornerRadius: 16)
            // Button-shape affordance (audit 6.3): plain-styled tappable row,
            // not inside a List. Corner radius matches `a11yCardBackground`
            // above (16, not the brief's literal 12) so the stroke traces
            // the card's own rounded fill instead of cutting across it.
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 40)
```

to:

```swift
        }
        .buttonStyle(ParchmentButtonStyle(theme: .zen, shape: .wide))
        .padding(.horizontal, 40)
```

(`ParchmentButtonStyle` already supplies padding/background/foreground — the manual `.padding(14)`/`.a11yCardBackground`/`.overlay(stroke)` chrome is removed entirely, not layered underneath.)

Do **not** touch the Serenity-count button (lines 51-69) — it's explicitly out of scope.

- [ ] **Step 3: Build**

Run: `xcodebuild build -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: **BUILD SUCCEEDED**.

- [ ] **Step 4: Run the existing menu accessibility audit**

Run: `xcodebuild test -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ZenWordOfDoomUITests/AccessibilityAuditTests/testMenuPassesAudit`
Expected: **TEST SUCCEEDED** — hit-region/Dynamic-Type audits still pass since `ParchmentButtonStyle` preserves the 44pt minimum frame.

- [ ] **Step 5: Commit**

```bash
git add App/ZenWordOfDoom/MenuView.swift
git commit -m "feat(app): reskin MenuView buttons with parchment chrome"
```

---

## Task 7: Wire `GameContainerView` controls (Clear/Shuffle/Submit)

**Files:**
- Modify: `App/ZenWordOfDoom/GameContainerView.swift`

**Interfaces:**
- Consumes: `ParchmentButtonStyle` (Task 4). Uses `levelService.theme(forID: level.id)`, already called inline elsewhere in this same view (e.g. `SceneRevealView`'s `theme:` argument) — follow that existing repeated-inline-call convention rather than introducing a new stored property.

- [ ] **Step 1: Replace the controls row's button styles**

In `App/ZenWordOfDoom/GameContainerView.swift`, the `controls` computed property (currently lines 328-357):

```swift
    private var controls: some View {
        HStack {
            Button("Clear", role: .destructive) { model.clear() }
                .buttonStyle(.bordered)
                .controlSize(.large)

            Spacer()

            Button {
                Haptics.tap()
                model.shuffle()
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityLabel("Shuffle letters")

            Spacer()

            Button("Submit") {
                Haptics.tap()
                model.submit()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.selection.count < GameEngine.minWordLength)
        }
    }
```

becomes:

```swift
    private var controls: some View {
        let theme = levelService.theme(forID: level.id)
        return HStack {
            Button("Clear", role: .destructive) { model.clear() }
                .buttonStyle(ParchmentButtonStyle(theme: theme, shape: .wide))

            Spacer()

            Button {
                Haptics.tap()
                model.shuffle()
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(ParchmentButtonStyle(theme: theme, shape: .icon))
            .accessibilityLabel("Shuffle letters")

            Spacer()

            Button("Submit") {
                Haptics.tap()
                model.submit()
            }
            .buttonStyle(ParchmentButtonStyle(theme: theme, shape: .wide))
            .disabled(model.selection.count < GameEngine.minWordLength)
        }
    }
```

- [ ] **Step 2: Build**

Run: `xcodebuild build -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: **BUILD SUCCEEDED**.

- [ ] **Step 3: Run the existing play-screen accessibility audit**

Run: `xcodebuild test -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ZenWordOfDoomUITests/AccessibilityAuditTests/testPlayScreenPassesAudit`
Expected: **TEST SUCCEEDED**.

- [ ] **Step 4: Commit**

```bash
git add App/ZenWordOfDoom/GameContainerView.swift
git commit -m "feat(app): reskin Clear/Shuffle/Submit with parchment chrome"
```

---

## Task 8: Wire `HUDView` (stat pills, hint/mic buttons, `DoomTimerView`)

**Files:**
- Modify: `App/ZenWordOfDoom/HUDView.swift`
- Modify: `App/ZenWordOfDoom/GameContainerView.swift`

**Interfaces:**
- Consumes: `ParchmentButtonStyle` (Task 4), `.parchmentReadout(theme:)` (Task 5).
- Produces: `HUDView` and `DoomTimerView` both gain a `theme: Theme` stored property — their one construction site (`GameContainerView.swift`) must pass it.

- [ ] **Step 1: Add `theme` to `HUDView` and reskin its pills/buttons**

In `App/ZenWordOfDoom/HUDView.swift`, add `import LevelGen` after the existing `import SwiftUI` (line 1), and add a stored property right after `let hintsEnabled: Bool` (currently line 21):

```swift
    let theme: Theme
```

Change the `stat(...)` helper (currently lines 63-79) to apply the new readout chrome. Its current body:

```swift
    private func stat(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(labelStyle)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(labelStyle)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }
```

becomes:

```swift
    private func stat(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(title)
                    .font(.caption2)
            }
        }
        .parchmentReadout(theme: theme)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }
```

`.parchmentReadout` already supplies a WCAG-pinned foreground color via `AccessibilityPalette.parchmentInk(for:)`, so the Increase-Contrast-specific `labelStyle` computed property and its backing `@Environment(\.colorSchemeContrast)` become fully unused once `stat(...)` no longer references them (nothing else in `HUDView.swift` — `hintButton`, `micButton` — ever used them either). Remove both declarations entirely: delete the `@Environment(\.colorSchemeContrast) private var contrast` line (currently line 27) and the `labelStyle` computed property (currently lines 34-37):

```swift
    /// Increase Contrast (audit 6.2): the caption labels default to
    /// `.secondary`, which can thin out over busy scene art; bump to
    /// `.primary` when the setting is on.
    private var labelStyle: Color { contrast == .increased ? .primary : .secondary }
```

(This whole block is deleted, along with the `@Environment(\.colorSchemeContrast) private var contrast` line above it — both are dead once `stat(...)` is updated below.)

Now update the outer `HStack` in `body` (currently lines 40-52) to drop the now-redundant outer chrome, since `stat(...)` and the buttons each carry their own chrome:

```swift
    var body: some View {
        HStack(spacing: 12) {
            stat(title: "Score", value: scoreVoided ? "\u{2014}" : "\(score)", systemImage: "star.fill")
            stat(title: "Serenity", value: "\(serenity)", systemImage: "leaf.fill")

            Spacer(minLength: 0)

            if hintsEnabled {
                hintButton
            }
            if voiceEnabled {
                micButton
            }
        }
    }
```

(This replaces the previous body, currently lines 39-61, which had `.padding(.horizontal, 14)`, `.padding(.vertical, 10)`, `.a11yCardBackground(cornerRadius: .infinity)`, and `.background(Capsule().fill(Color.black.opacity(0.25)))` on the whole `HStack` — those are removed since each child now supplies its own parchment background instead of one shared pill wrapping everything.)

Change `hintButton` (currently lines 81-101) from its own `Circle()`-filled background to `ParchmentButtonStyle`:

```swift
    private var hintButton: some View {
        Button(action: onHint) {
            Label("Hint", systemImage: "lightbulb.fill")
                .labelStyle(.iconOnly)
                .font(.title3)
        }
        .buttonStyle(ParchmentButtonStyle(theme: theme, shape: .icon))
        .disabled(!canAffordHint)
        .accessibilityLabel("Reveal a hint for \(hintCost) serenity")
        .accessibilityHint(canAffordHint ? "" : "Not enough serenity")
    }
```

Change `micButton` (currently lines 103-121) the same way:

```swift
    private var micButton: some View {
        Button(action: { isListening ? onMicStop() : onMicStart() }) {
            Image(systemName: isListening ? "mic.fill" : "mic")
                .font(.title3)
                .symbolEffect(.pulse, isActive: isListening && !reduceMotion)
        }
        .buttonStyle(ParchmentButtonStyle(theme: theme, shape: .icon))
        .accessibilityLabel(isListening ? "Stop listening" : "Speak a word")
    }
```

(`canAffordHint`'s red/gray fill and mic's red/secondary fill are dropped — `ParchmentButtonStyle` already renders a disabled/enabled visual via `.saturation`/`.opacity`; the mic's listening-vs-not distinction is carried entirely by the SF Symbol swap (`mic.fill` vs `mic`) plus the pulse effect, which is enough signal on its own.)

- [ ] **Step 2: Add `theme` to `DoomTimerView` and reskin it**

In the same file, `DoomTimerView` (currently lines 128-151):

```swift
struct DoomTimerView: View {
    let timeRemaining: TimeInterval
    let theme: Theme

    var body: some View {
        let secs = max(0, Int(timeRemaining.rounded()))
        let mm = secs / 60
        let ss = secs % 60
        let urgent = timeRemaining <= 15
        HStack(spacing: 4) {
            Image(systemName: "hourglass")
                .font(.caption)
            Text(String(format: "%d:%02d", mm, ss))
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(urgent ? Color.red : Color.primary)
        .parchmentReadout(theme: theme)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Time remaining \(mm) minutes \(ss) seconds")
    }
}
```

(`.foregroundStyle(urgent ? Color.red : Color.primary)` is applied to the `HStack` *before* `.parchmentReadout(theme:)`, so `.parchmentReadout`'s own `AccessibilityPalette.parchmentInk(for:)` color — applied inside the modifier to `content`, i.e. after this — wins for the non-urgent case by view-modifier ordering... actually SwiftUI resolves the *innermost* explicit `.foregroundStyle` for `Text`, so `Color.red` when urgent will still show through correctly since it's set directly, and non-urgent `Color.primary` is overridden by `parchmentReadout`'s ink color, which is fine — `Color.primary` was only ever a neutral default here, not a deliberate pinned choice, so `parchmentInk(for:)` taking over is the intended behavior, not a bug.)

- [ ] **Step 3: Update the two `Preview`s in this file**

The `#Preview` block (currently lines 153-183) constructs both `DoomTimerView` and `HUDView` without a `theme:` argument. Replace the whole block:

```swift
#Preview {
    VStack {
        DoomTimerView(timeRemaining: 92, theme: .zen)
        HUDView(
            score: 320,
            scoreVoided: false,
            serenity: 25,
            hintCost: 5,
            isListening: false,
            voiceEnabled: true,
            hintsEnabled: true,
            theme: .zen,
            onHint: {},
            onMicStart: {},
            onMicStop: {}
        )
        HUDView(
            score: 0,
            scoreVoided: true,
            serenity: 2,
            hintCost: 5,
            isListening: true,
            voiceEnabled: true,
            hintsEnabled: true,
            theme: .zen,
            onHint: {},
            onMicStart: {},
            onMicStop: {}
        )
    }
    .padding()
    .background(Color.black)
}
```

- [ ] **Step 4: Pass `theme:` from the one real construction site**

In `App/ZenWordOfDoom/GameContainerView.swift`, the `DoomTimerView`/`HUDView` construction (currently lines 100-121):

```swift
                        if let timeRemaining = model.timeRemaining {
                            DoomTimerView(timeRemaining: timeRemaining)
                        }

                        HUDView(
                            score: model.score,
                            scoreVoided: model.doomExpired,
                            serenity: model.serenity,
                            hintCost: model.hintCost,
                            isListening: voice.isListening,
                            voiceEnabled: settings.voiceEnabled,
                            hintsEnabled: model.hintsAvailable,
                            onHint: {
                                Haptics.reveal()
                                model.useHintRevealCell()
                            },
                            onMicStart: { startListening() },
                            onMicStop: { voice.stop() }
                        )
```

becomes:

```swift
                        if let timeRemaining = model.timeRemaining {
                            DoomTimerView(timeRemaining: timeRemaining, theme: levelService.theme(forID: level.id))
                        }

                        HUDView(
                            score: model.score,
                            scoreVoided: model.doomExpired,
                            serenity: model.serenity,
                            hintCost: model.hintCost,
                            isListening: voice.isListening,
                            voiceEnabled: settings.voiceEnabled,
                            hintsEnabled: model.hintsAvailable,
                            theme: levelService.theme(forID: level.id),
                            onHint: {
                                Haptics.reveal()
                                model.useHintRevealCell()
                            },
                            onMicStart: { startListening() },
                            onMicStop: { voice.stop() }
                        )
```

- [ ] **Step 5: Build**

Run: `xcodebuild build -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: **BUILD SUCCEEDED**.

- [ ] **Step 6: Run the play-screen accessibility audit**

Run: `xcodebuild test -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ZenWordOfDoomUITests/AccessibilityAuditTests/testPlayScreenPassesAudit`
Expected: **TEST SUCCEEDED**. If the `.dynamicType` bypass closure in that test (which special-cases `"Score"`/`"Serenity"`-prefixed labels — see the comment block in `AccessibilityAuditTests.swift`) starts failing for a *different* reason now, re-read that comment before changing anything; the bypass logic itself should still apply unchanged since the accessibility label text didn't change, only the visual chrome behind it.

- [ ] **Step 7: Commit**

```bash
git add App/ZenWordOfDoom/HUDView.swift App/ZenWordOfDoom/GameContainerView.swift
git commit -m "feat(app): reskin HUDView and DoomTimerView with parchment chrome"
```

---

## Task 9: Wire `WordRibbonView` and `FoundWordsTray`

**Files:**
- Modify: `App/ZenWordOfDoom/WordRibbonView.swift`
- Modify: `App/ZenWordOfDoom/MetaViews.swift`
- Modify: `App/ZenWordOfDoom/GameContainerView.swift`

**Interfaces:**
- Consumes: `.parchmentReadout(theme:)` (Task 5).
- **Correction from the design spec:** `FoundWordsTray`'s existing chrome (`.a11yCardBackground(cornerRadius: .infinity)`) is applied per-bonus-word tag inside its horizontal scroll, not to a single outer "progress pill" as the spec's prose says — the `progress` text itself (e.g. "3/7 words") has no background at all today. This task reskins the per-tag chrome, which is the actual translucent-card element that exists; it does not add new chrome around `progress` that wasn't there before.

- [ ] **Step 1: Add `theme` to `WordRibbonView`**

In `App/ZenWordOfDoom/WordRibbonView.swift`, add `import LevelGen` after `import SwiftUI` (line 1), add `let theme: Theme` after `let word: String` (currently line 9), and change `letterTile(_:)` (currently lines 36-48):

```swift
    private func letterTile(_ letter: Character) -> some View {
        Text(String(letter))
            .font(.system(.title2, design: .rounded).weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: tileSide, height: tileSide)
            .parchmentReadout(theme: theme)
    }
```

(Drops the old `.foregroundStyle(.white)` / `RoundedRectangle` fill / `.shadow(radius: 1)` — `.parchmentReadout` supplies both the background and a WCAG-pinned foreground color.)

Change `placeholder` (currently lines 50-57) similarly:

```swift
    private var placeholder: some View {
        Text("Trace a word")
            .font(.system(.subheadline, design: .rounded))
            .parchmentReadout(theme: theme)
    }
```

Update the `#Preview` (currently lines 60-67) to pass `theme:`, e.g. `WordRibbonView(word: "", theme: .zen)` and `WordRibbonView(word: "STONE", theme: .zen)`.

- [ ] **Step 2: Add `theme` to `FoundWordsTray`**

In `App/ZenWordOfDoom/MetaViews.swift`, `FoundWordsTray` (currently lines 6-38) already sits in a file with `import LevelGen` (line 2) already present. Add `let theme: Theme` after `let bonusWords: [String]` (currently line 8), and change the per-tag chrome (currently lines 24-29):

```swift
                        ForEach(bonusWords.reversed(), id: \.self) { word in
                            Text(word)
                                .font(.caption2.weight(.medium))
                                .parchmentReadout(theme: theme)
                        }
```

(Drops the old `.padding(.horizontal, 8)` / `.padding(.vertical, 4)` / `.a11yCardBackground(cornerRadius: .infinity)` — `.parchmentReadout` supplies its own padding and background.)

- [ ] **Step 3: Pass `theme:` from the two real construction sites**

In `App/ZenWordOfDoom/GameContainerView.swift`:

```swift
                        FoundWordsTray(progress: model.progressLabel, bonusWords: model.bonusWords)

                        WordRibbonView(word: model.currentWord)
```

(currently lines 165 and 167) becomes:

```swift
                        FoundWordsTray(progress: model.progressLabel, bonusWords: model.bonusWords, theme: levelService.theme(forID: level.id))

                        WordRibbonView(word: model.currentWord, theme: levelService.theme(forID: level.id))
```

- [ ] **Step 4: Build**

Run: `xcodebuild build -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: **BUILD SUCCEEDED**.

- [ ] **Step 5: Run the play-screen accessibility audit**

Run: `xcodebuild test -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ZenWordOfDoomUITests/AccessibilityAuditTests/testPlayScreenPassesAudit`
Expected: **TEST SUCCEEDED**. If the `.dynamicType` bypass closure for single-letter wheel-tile-style labels (see the second bypass block in `AccessibilityAuditTests.swift`, which matches `label.count == 1, label.first?.isLetter == true`) starts also catching the new letter-ribbon tiles unexpectedly, that's fine — they're a different view (`WordRibbonView`, not `WheelView`'s `TileView`) but the same single-letter-label shape, so the existing bypass reasoning (capped size at accessibility Dynamic Type, same as documented there) applies equally; no code change needed, just note it if you see it.

- [ ] **Step 6: Commit**

```bash
git add App/ZenWordOfDoom/WordRibbonView.swift App/ZenWordOfDoom/MetaViews.swift App/ZenWordOfDoom/GameContainerView.swift
git commit -m "feat(app): reskin WordRibbonView and FoundWordsTray with parchment chrome"
```

---

## Task 10: Full verification pass

**Files:** none (verification only).

**Interfaces:** none — this task consumes everything built in Tasks 1-9 and confirms it holds together.

- [ ] **Step 1: Full package + app unit test suite**

Run: `swift test`
Expected: **all tests pass** (this plan doesn't touch `Sources/`, so this is a regression check).

Run: `xcodegen generate && xcodebuild test -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ZenWordOfDoomTests`
Expected: **TEST SUCCEEDED**, including `WCAGContrastTests.testParchmentPairsMeetAA` and `ParchmentChromeTests`.

- [ ] **Step 2: Full accessibility audit suite**

Run: `xcodebuild test -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ZenWordOfDoomUITests/AccessibilityAuditTests`
Expected: **TEST SUCCEEDED** for all four tests (menu, level select, play screen, settings — settings is untouched by this plan and should be unaffected).

- [ ] **Step 3: Manual on-device/simulator visual check — SKIPPED**

Deferred by explicit user decision: visual verification (parchment texture rendering, Dynamic Type behavior, press/disabled states, Reduce Motion) will be done via a real TestFlight build instead of in-session simulator screenshots. Do not attempt simulator screenshots/launches for this step — move straight to Step 4.

- [ ] **Step 4: Final commit (skip — nothing to commit since Step 3 was skipped)**

```bash
git add -A
git commit -m "fix(app): address visual issues found in parchment-chrome verification pass"
```

(Skip this step entirely if Step 3 found nothing to fix.)
