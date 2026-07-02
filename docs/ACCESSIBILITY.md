# Accessibility

Companion to [`ARCHITECTURE.md`](ARCHITECTURE.md). Zen Word of Doom targets
**WCAG 2.2 AA**, plus Apple's HIG/Accessibility guidance for iOS, across
Dynamic Type, VoiceOver, color contrast, touch targets, and the Reduce
Motion / Reduce Transparency / Increase Contrast system settings. This
document is the conformance summary and the pre-release checklist; the
underlying audit and design decisions are in
[`docs/superpowers/specs/2026-07-02-v0.4-accessibility-design.md`](superpowers/specs/2026-07-02-v0.4-accessibility-design.md).

## Conformance summary

**Dynamic Type & reflow.** `GamePlayView` and `MenuView` scroll their main
content, so nothing becomes unreachable as text size grows — verified up to
AX5 (accessibility-extra-extra-extra-large). Wheel and word-ribbon tile
sizing use `@ScaledMetric(relativeTo:)` with a 44pt floor (touch target) and
a geometry-derived cap so a full 9-tile wheel keeps fitting; see
`App/ZenWordOfDoom/WheelView.swift`. Grid letters use a `minimumScaleFactor`
as a belt-and-braces clamp. Previously fixed-point titles/scores now
participate in Dynamic Type via text styles or `relativeTo:`-scaled metrics.

**VoiceOver.** The crossword grid is exposed as an accessibility container
labeled `"Crossword grid, X of Y words solved"`, with each slot as one
element (e.g. `"5-letter word, across — solved: STONE"` or `"4-letter word,
down — S, blank, O, blank"`); see `GridView.slotDescription`, covered by
`App/ZenWordOfDoomTests/GridAccessibilityTests.swift`. Meaningful game
events (word found, bonus, invalid, hint reveal, doom-timer thresholds, doom
expiry, level clear) post real VoiceOver announcements through the
`AccessibilityAnnouncing` seam (`App/ZenWordOfDoom/AccessibilityAnnouncer.swift`)
— `SystemAnnouncer` posts `AccessibilityNotification.Announcement` in the
app; a null implementation keeps view-model tests deterministic. Overlays
(`LevelClearView`, `DoomExpiredOverlay`) hide the gameplay stack from the
accessibility tree while shown and move VoiceOver focus to the overlay
heading. Each wheel tile carries a named custom accessibility action
(`.accessibilityAction(named: "Select <letter>")`) as a guaranteed
programmatic activation path, plus a default `.accessibilityAction` and the
`.isButton` trait so plain double-tap works too — independent of the
drag-gesture recognizer used for sighted play.

**Contrast.** `App/ZenWordOfDoom/AccessibilityPalette.swift` holds every
fixed color pair the app relies on for contrast — deliberately opting out of
scheme-adaptive colors at the handful of sites where adaptive color produced
a near-invisible pairing (dark-mode wheel tiles, solved crossword letters).
Each pair is computed with the real WCAG relative-luminance/contrast-ratio
math and pinned by `App/ZenWordOfDoomTests/WCAGContrastTests.swift`: text
pairs assert ≥ 4.5:1, UI-component pairs (e.g. grid cell stroke vs. fill)
assert ≥ 3:1. `AccessibilityPalette` also exposes separate, unpinned
Increase-Contrast variants for the marginal pairs (unfilled grid cell fill,
grid cell stroke) used only when `colorSchemeContrast == .increased`.

**Touch targets.** All interactive controls — wheel tiles, HUD hint/mic
buttons, play controls, overlay Continue buttons, store price buttons — meet
or exceed the 44×44pt floor, including under Dynamic Type scaling (wheel
tiles are clamped to a 44pt floor as they scale).

**Reduce Motion / Reduce Transparency / Increase Contrast.** The mic's pulse
animation is gated on `!reduceMotion`. `App/ZenWordOfDoom/A11yCardBackground.swift`
provides a shared `a11yCardBackground(cornerRadius:)` modifier applied to
every material-backed card/capsule (grid, HUD, LevelClear/DoomExpired cards,
bonus capsule, pack banner, daily card): it renders `.ultraThinMaterial`
normally and swaps to an opaque fill under
`accessibilityReduceTransparency`. `AccessibilityPalette`'s Increase-Contrast
variants darken/strengthen the marginal pairs when
`colorSchemeContrast == .increased`. No new user-facing settings were added
— everything responds to the system's existing accessibility settings.

## Already good (preserved, not reinvented)

These patterns predate the v0.4 accessibility pass and were used as the
templates for the work above rather than being replaced:

- **Voice input** (on-device speech recognition) is a full third input
  method alongside tap and swipe, and stands as a built-in motor-accessibility
  path independent of anything added in this pass.
- **`CutSceneView`'s reduce-motion timeline** — the between-levels cut scene
  already had a reduced-motion-aware presentation before this pass.
- **`.sheet()`-based modal containment** — sheets already give VoiceOver
  users correct modal focus/dismissal semantics for free via UIKit.
- **`.accessibilityElement(children: .combine)` rows** (e.g. `StatsView.row`,
  `HUDView.stat`) — an existing pattern for turning an icon+label(s) cluster
  into one coherent VoiceOver element, reused for `BestiaryView` rows in this
  pass.
- **56pt wheel touch targets** — the wheel's tiles were already comfortably
  above the 44pt floor at the default content size category; the v0.4 work
  only added the `@ScaledMetric` floor/cap so that stays true under Dynamic
  Type.

## Release checklist

Automated coverage (contrast math, grid VoiceOver descriptions, and the
on-device accessibility audit) is enforced in CI. The following need a human
with a device or simulator and are **not** currently automatable in this
repo's CI/sandbox environment:

- [ ] **VoiceOver wheel-tile activation, on device.** Each wheel tile carries
  a named custom action (`.accessibilityAction(named: "Select <letter>")`),
  which is the guaranteed activation path — plus a default
  `.accessibilityAction` and the `.isButton` trait so a plain double-tap
  works too, in case the wheel's `DragGesture` ever intercepts standard
  activation (see the comment in `WheelView.swift`). The named action is
  exercised by nothing headless can drive interactively; every review on
  this branch flagged that CI/sandbox environments can't drive a real
  VoiceOver session. Confirm the primary double-tap-to-activate path also
  works via Accessibility Inspector or an on-device VoiceOver walk of the
  wheel.
- [ ] **AX5 reflow pass on an iPhone SE-class device.** Automated screenshots
  during the Dynamic Type fix loop confirmed reachability at AX5 in the
  simulator; do a fresh human pass on an SE-class (smallest supported)
  device after all v0.4 work has landed.
- [ ] **Reduce Transparency / Increase Contrast visual pass.** Both toggles'
  behavior was verified against Apple's documented modifier semantics and by
  code inspection (`A11yCardBackground.swift`, `AccessibilityPalette`'s
  Increase-Contrast variants), not by interactively toggling either setting
  on device. Do that pass before release.
- [ ] **Accessibility Inspector full audit** of the menu, level select, play,
  and settings screens, as a cross-check against the automated
  `AccessibilityAuditTests` UI test target (see below).

**Note on the wheel-height cap:** an earlier draft of the Dynamic Type work
specified a 320pt cap for the wheel's `wheelHeight`. Review found a real
geometric overlap at accessibility text sizes with that number; the cap was
independently re-derived and verified by two separate reviewers and shipped
as **350pt** (`WheelView.scaledWheelHeight`'s cap in
`App/ZenWordOfDoom/WheelView.swift`). If you encounter the 320pt figure in an
older planning doc, treat 350pt as authoritative.

## Running the automated checks

Contrast-pair math (fast, no simulator):

```sh
swift test --filter WCAGContrastTests
```

Grid VoiceOver description coverage runs as part of the app's Xcode test
target (`ZenWordOfDoomTests`) — needs `xcodebuild test` against a
scheme/simulator, since it's `@testable import ZenWordOfDoom`:

```sh
xcodegen generate
xcodebuild -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:ZenWordOfDoomTests/GridAccessibilityTests test
```

The on-device accessibility audit — iOS 17's `performAccessibilityAudit()`
over the menu, level select, play, and settings screens, checking
`.dynamicType`, `.elementDetection`, and `.hitRegion` — lives in the
`ZenWordOfDoomUITests` target, `AccessibilityAuditTests.swift`. Run it the
same way as any UI test target, once it's part of your generated project:

```sh
xcodegen generate
xcodebuild -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:ZenWordOfDoomUITests/AccessibilityAuditTests test
```

`.contrast` is deliberately excluded from that audit's type set: several
screens sit on photographic hero backdrops chosen randomly per launch, so a
contrast audit over those screens would be nondeterministic; `WCAGContrastTests`
covers contrast deterministically instead, over the app's fixed color pairs.
