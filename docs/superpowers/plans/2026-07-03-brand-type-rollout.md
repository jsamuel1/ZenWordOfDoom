# Brand Type Rollout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the app's bundled Buda/Grenze Gotisch brand type — already live on the menu title — to the level-clear headline, the pack-banner name (both theme-reactive), and the Bestiary/Shrine nav titles (fixed pairing).

**Architecture:** One new pure helper (`BrandFont.themed(_:size:relativeTo:)`) added to the existing `App/ZenWordOfDoom/BrandFont.swift`. `LevelClearView` and `PackBannerView` each gain a `theme: Theme` stored property threaded in from `GameContainerView.swift`, where `levelService.theme(forID:)` is already computed. `BestiaryView`/`ShrineView` swap their plain `.navigationTitle(String)` for `.navigationTitle("")` + a `.toolbar` principal item styled with a fixed `BrandFont` call.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest (`@testable import ZenWordOfDoom`), XcodeGen (`project.yml`).

## Global Constraints

- PostScript lookup keys are `Buda-Light` (Zen) and `GrenzeGotisch-Bold` (Doom) — always go through `BrandFont`, never call `Font.custom` directly with these strings (source: `BrandFont.swift`).
- `Theme` is `Sources/LevelGen/Theme.swift`: `public enum Theme: String, CaseIterable, Codable, Sendable { case zen; case doom }`. Do not add a `Font`-returning API to this type or to the `LevelGen` package — the mapping stays in the App target (spec §3.3, §4.1).
- Only the four elements named in the spec get brand type: `LevelClearView`'s `"Level Cleared"` text, `PackBannerView`'s `pack.name` text, and the `BestiaryView`/`ShrineView` nav titles. Score/serenity/creature-name text, `pack.flavor`, cut-scene screens, and the Stats/Settings nav titles are explicitly unchanged (spec §2 non-goals).
- Point sizes (24, 20, 22) are starting values, tunable on-device if they clip or read wrong at accessibility Dynamic Type sizes (spec §4, closing note) — do not treat them as exact requirements if on-device verification says otherwise.
- This repo has no SwiftUI snapshot/ViewInspector testing library (confirmed: only plain XCTest via `@testable import ZenWordOfDoom`, see `App/ZenWordOfDoomTests/WCAGContrastTests.swift`). View-level styling changes are verified by building and running the app on-device/simulator, not by automated UI test, matching how the original `MenuView` brand-type change was verified in this project.

---

### Task 1: `BrandFont.themed` helper

**Files:**
- Modify: `App/ZenWordOfDoom/BrandFont.swift`
- Test: `App/ZenWordOfDoomTests/BrandFontThemedTests.swift` (new)

**Interfaces:**
- Consumes: `Theme` (`import LevelGen`; `Theme.zen` / `Theme.doom`), the existing `BrandFont.zen(size:relativeTo:)` and `BrandFont.doom(size:relativeTo:)` statics.
- Produces: `BrandFont.themed(_ theme: Theme, size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font`, consumed by Task 2 and Task 3.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import SwiftUI
import LevelGen
@testable import ZenWordOfDoom

final class BrandFontThemedTests: XCTestCase {
    func testDoomThemeUsesGrenzeGotisch() {
        XCTAssertEqual(
            BrandFont.themed(.doom, size: 22, relativeTo: .headline),
            BrandFont.doom(size: 22, relativeTo: .headline)
        )
    }

    func testZenThemeUsesBuda() {
        XCTAssertEqual(
            BrandFont.themed(.zen, size: 22, relativeTo: .headline),
            BrandFont.zen(size: 22, relativeTo: .headline)
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter BrandFontThemedTests 2>&1 | tail -30` from the repo root (or, if that target isn't reachable via `swift test` because it's hosted in the Xcode app target, run `xcodebuild test -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ZenWordOfDoomTests/BrandFontThemedTests 2>&1 | tail -60` after `xcodegen generate`).
Expected: FAIL to build — `BrandFont.themed` does not exist.

- [ ] **Step 3: Write minimal implementation**

Add to `App/ZenWordOfDoom/BrandFont.swift`, inside `enum BrandFont { ... }`, after the existing `doom(...)` static:

```swift
    /// Picks `.zen` or `.doom` by the given `Theme` — the single place this
    /// mapping is written, so call sites never duplicate the ternary.
    static func themed(_ theme: Theme, size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        theme == .doom ? doom(size: size, relativeTo: textStyle) : zen(size: size, relativeTo: textStyle)
    }
```

Add `import LevelGen` to the top of `App/ZenWordOfDoom/BrandFont.swift` (it currently only imports `SwiftUI`).

- [ ] **Step 4: Run test to verify it passes**

Run the same command as Step 2.
Expected: PASS (2 tests, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add App/ZenWordOfDoom/BrandFont.swift App/ZenWordOfDoomTests/BrandFontThemedTests.swift
git commit -m "feat(app): add BrandFont.themed(_:size:relativeTo:) helper"
```

---

### Task 2: Theme-reactive level-clear headline

**Files:**
- Modify: `App/ZenWordOfDoom/LevelClearView.swift`
- Modify: `App/ZenWordOfDoom/GameContainerView.swift:227`

**Interfaces:**
- Consumes: `BrandFont.themed(_:size:relativeTo:)` (Task 1), `Theme` (`import LevelGen`, already imported by `GameContainerView.swift`), `levelService.theme(forID:)` (existing, already called at `GameContainerView.swift:204`).
- Produces: `LevelClearView.init(summary:theme:reducedMotion:onContinue:)` — the `theme` parameter's position matters for Task 2's own call-site update and for the `#Preview` block; no later task depends on this signature.

- [ ] **Step 1: Update the view's stored properties and body**

In `App/ZenWordOfDoom/LevelClearView.swift`, add `import LevelGen` at the top (needed for the `Theme` type), add a `let theme: Theme` stored property, and change the `"Level Cleared"` text's font:

```swift
import SwiftUI
import LevelGen

/// The payoff shown when a level is cleared: the score counts up, serenity earned
/// is celebrated, and a newly revealed Doom creature gets a fanfare line. Appears
/// over the held creature reveal during the completion beat, then the play screen
/// advances to the cut scene (spec workstream C — the missing dopamine beat).
struct ClearSummary: Equatable {
    let score: Int
    let serenityEarned: Int
    /// Non-nil only when this clear revealed a creature not seen before.
    let newCreatureID: String?
}

struct LevelClearView: View {
    let summary: ClearSummary
    let theme: Theme
    let reducedMotion: Bool
    let onContinue: () -> Void

    @State private var shownScore = 0
    @State private var appeared = false

    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 44
    @AccessibilityFocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 14) {
                Text("Level Cleared")
                    .font(BrandFont.themed(theme, size: 24, relativeTo: .title2))
```

Leave every other line in the file (score, serenity label, creature name block, button, `animateIn()`, `prettyName(_:)`, `accessibilityText`) exactly as-is — only the property list, the import, and the one `.font(...)` call change.

Update the `#Preview` block at the bottom of the same file to pass the new parameter:

```swift
#Preview {
    ZStack {
        Color.black
        LevelClearView(
            summary: ClearSummary(score: 486, serenityEarned: 15, newCreatureID: "bone-wraith"),
            theme: .doom,
            reducedMotion: false,
            onContinue: {}
        )
    }
}
```

- [ ] **Step 2: Update the construction site**

In `App/ZenWordOfDoom/GameContainerView.swift`, change line 227 from:

```swift
                    LevelClearView(summary: summary, reducedMotion: reduceMotion) {
```

to:

```swift
                    LevelClearView(summary: summary, theme: levelService.theme(forID: level.id), reducedMotion: reduceMotion) {
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodegen generate && xcodebuild build -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -40`
Expected: `** BUILD SUCCEEDED **`. (No new automated test here — this is a pure SwiftUI styling/parameter change with no testing library capable of asserting rendered font in this repo; verified on-device in Task 4.)

- [ ] **Step 4: Commit**

```bash
git add App/ZenWordOfDoom/LevelClearView.swift App/ZenWordOfDoom/GameContainerView.swift
git commit -m "feat(app): theme-reactive brand font on Level Cleared headline"
```

---

### Task 3: Theme-reactive pack banner name

**Files:**
- Modify: `App/ZenWordOfDoom/MetaViews.swift`
- Modify: `App/ZenWordOfDoom/GameContainerView.swift:214`

**Interfaces:**
- Consumes: `BrandFont.themed(_:size:relativeTo:)` (Task 1), `Theme` (`import LevelGen`), `levelService.theme(forID:)` (existing).
- Produces: `PackBannerView.init(pack:theme:)`.

- [ ] **Step 1: Update `PackBannerView`**

In `App/ZenWordOfDoom/MetaViews.swift`, add a `let theme: Theme` stored property and change `pack.name`'s font. If the file doesn't already `import LevelGen`, add it — `Pack` is already a `LevelGen` type used by this file, so check first with `grep -n "^import" App/ZenWordOfDoom/MetaViews.swift` before editing, and only add the import if it's missing.

```swift
struct PackBannerView: View {
    let pack: Pack
    let theme: Theme

    var body: some View {
        VStack(spacing: 4) {
            Text(pack.name)
                .font(BrandFont.themed(theme, size: 20, relativeTo: .title3))
            if !pack.flavor.isEmpty {
                Text(pack.flavor)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .a11yCardBackground(cornerRadius: 16)
        .shadow(radius: 8, y: 4)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pack: \(pack.name). \(pack.flavor)")
```

(Leave the rest of `PackBannerView`'s body — everything after `.accessibilityLabel(...)` — and the rest of the file untouched.)

If `MetaViews.swift` has a `#Preview` that constructs `PackBannerView(pack: ...)`, add `theme: .zen` (or `.doom`) to it so the file keeps compiling — check with `grep -n "PackBannerView(" App/ZenWordOfDoom/MetaViews.swift` and update every call site found, not just the ones described above.

- [ ] **Step 2: Update the construction site**

In `App/ZenWordOfDoom/GameContainerView.swift`, change line 214 from:

```swift
                PackBannerView(pack: pack)
```

to:

```swift
                PackBannerView(pack: pack, theme: levelService.theme(forID: level.id))
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodegen generate && xcodebuild build -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -40`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add App/ZenWordOfDoom/MetaViews.swift App/ZenWordOfDoom/GameContainerView.swift
git commit -m "feat(app): theme-reactive brand font on pack banner name"
```

---

### Task 4: Fixed brand-font nav titles for Bestiary and Shrine

**Files:**
- Modify: `App/ZenWordOfDoom/BestiaryView.swift:28-29`
- Modify: `App/ZenWordOfDoom/ShrineView.swift:39-40`

**Interfaces:**
- Consumes: `BrandFont.doom(size:relativeTo:)`, `BrandFont.zen(size:relativeTo:)` (both pre-existing, Task 1 not required for this task).
- Produces: nothing consumed by later tasks — this is the last code task.

- [ ] **Step 1: Update `BestiaryView`'s nav title**

In `App/ZenWordOfDoom/BestiaryView.swift`, replace lines 28-29:

```swift
        .navigationTitle("Bestiary")
        .navigationBarTitleDisplayMode(.inline)
```

with:

```swift
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Bestiary")
                    .font(BrandFont.doom(size: 22, relativeTo: .headline))
                    .accessibilityLabel("Bestiary")
            }
        }
```

- [ ] **Step 2: Update `ShrineView`'s nav title**

In `App/ZenWordOfDoom/ShrineView.swift`, replace lines 39-40:

```swift
        .navigationTitle("Shrine")
        .navigationBarTitleDisplayMode(.inline)
```

with:

```swift
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Shrine")
                    .font(BrandFont.zen(size: 22, relativeTo: .headline))
                    .accessibilityLabel("Shrine")
            }
        }
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodegen generate && xcodebuild build -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -40`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add App/ZenWordOfDoom/BestiaryView.swift App/ZenWordOfDoom/ShrineView.swift
git commit -m "feat(app): fixed brand-font nav titles for Bestiary and Shrine"
```

---

### Task 5: Full test suite + on-device verification

**Files:** none (verification-only task).

**Interfaces:**
- Consumes: everything from Tasks 1-4.
- Produces: nothing — this is the terminal task.

- [ ] **Step 1: Run the full unit test suite**

Run: `xcodegen generate && xcodebuild test -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -80`
Expected: all tests pass, including `BrandFontThemedTests` from Task 1, with no new failures in `LevelServiceTests`, `GameViewModelTests`, or any other existing suite.

- [ ] **Step 2: On-device/simulator visual verification**

Launch the app in the simulator (`xcodebuild -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' build` then run via Xcode or `xcrun simctl launch booted wtf.sauhsoj.zenwordofdoom` after install). Verify, and note any font-size adjustment needed against the "starting values, tunable" allowance in Global Constraints:

- Clear a Zen-themed level: "Level Cleared" renders in Buda; clear a Doom-themed level: renders in Grenze Gotisch. Score/serenity/creature-name text is unchanged (system font).
- Trigger a pack banner on a Zen-themed level and a Doom-themed level: the pack name renders in the matching brand face; the flavor caption stays system font.
- Open Bestiary from the main menu: nav title reads "Bestiary" in Grenze Gotisch, regardless of which pack/theme was last played.
- Open Shrine from the main menu: nav title reads "Shrine" in Buda, regardless of which pack/theme was last played.
- Open Stats and Settings: nav titles are unchanged plain system font (regression check — confirms Task 4 didn't touch these files).
- With VoiceOver on (Settings → Accessibility → VoiceOver, or Simulator's Accessibility Inspector), focus the Bestiary and Shrine nav titles and confirm they announce "Bestiary" / "Shrine" via the `.accessibilityLabel` set in Task 4.

- [ ] **Step 3: Report results**

If any point size reads wrong (clipped at accessibility sizes, or visually too small/large against the pre-existing chrome), adjust the `size:` argument at that one call site (`LevelClearView.swift`, `MetaViews.swift`, `BestiaryView.swift`, or `ShrineView.swift`) and re-run Step 2 for that screen only — this is within the "tunable starting values" allowance in Global Constraints, not a spec deviation requiring re-approval. No commit is required for this task itself unless a size tweak was made, in which case:

```bash
git add <changed file>
git commit -m "fix(app): tune brand-font size on <screen> after on-device check"
```
