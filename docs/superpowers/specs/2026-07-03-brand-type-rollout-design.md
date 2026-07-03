# Brand Type Rollout

**Status:** Design approved (brainstorm), pending implementation plan.
**Date:** 2026-07-03

## 1. Summary

The app's two bundled brand faces — Buda (Zen) and Grenze Gotisch (Doom),
already registered via `UIAppFonts` and exposed through `BrandFont.zen(...)`
/ `BrandFont.doom(...)` in [`BrandFont.swift`](../../../App/ZenWordOfDoom/BrandFont.swift) —
are live today only on the menu title
([`MenuView.swift:41-47`](../../../App/ZenWordOfDoom/MenuView.swift)). This
spec extends that same restrained "display face for headline moments only"
treatment to three more spots: the level-clear celebration, pack banners, and
two of the four secondary-screen nav titles.

## 2. Goals / non-goals

**Goals**
- Theme-reactive brand type on the level-clear "Level Cleared" headline and
  the pack-banner pack name — Zen-themed levels/packs render in Buda,
  Doom-themed ones in Grenze Gotisch, using the app's existing
  `Theme` (`.zen`/`.doom`) mechanism.
- Fixed (non-reactive) brand type on two secondary nav titles, matched to
  each screen's own vibe rather than the current pack: Bestiary (creature
  catalog) → Grenze Gotisch, Shrine (cosmetic garden) → Buda.
- Keep the mapping logic in one place (`BrandFont`, App target) rather than
  duplicated at each call site.

**Non-goals**
- Cut-scene "breath" screens — no title element exists there today (only
  poem lines + a Continue button), and the original design intent is for
  that text to stay calm/plain. Explicitly dropped from scope.
- Stats and Settings nav titles — dense/numeric utility screens where a
  display face would hurt legibility. Stay plain system font, untouched.
- Any other MenuView text (secondary buttons, "Today's Doom" daily card),
  score/serenity/creature-name text inside the level-clear card, or
  `pack.flavor` subtitle text inside the pack banner — all stay system font.
  The website's own convention (display fonts for headlines only, body text
  stays plain) is the guide for what counts as a "headline moment" here.
- Adding a `Font`-returning API to `Theme` itself, or to the `LevelGen`
  package in general — see §4.1.

## 3. Key decisions (from brainstorm)

1. **Scope:** level-clear headline + pack banner name (theme-reactive),
   Bestiary + Shrine nav titles (fixed pairing). Cut-scene dropped, Stats/
   Settings unchanged — both resolved directly with the user rather than
   guessed.
2. **Theme source:** the existing `Theme` enum
   (`Sources/LevelGen/Theme.swift`: `case zen, doom`), looked up via
   `levelService.theme(forID:)` — already computed at both relevant call
   sites in `GameContainerView.swift`, so no new theme-lookup plumbing is
   needed.
3. **Where the mapping logic lives:** the App target (`BrandFont.swift`),
   not `LevelGen`. `Theme` is a plain `Codable` enum with zero SwiftUI
   dependency today; giving it a `Font`-returning method would pull a UI
   concern into a package that has none. Rejected as an approach.
4. **Nav title styling mechanism:** SwiftUI's `.navigationTitle(String)`
   always renders in the system font — there is no direct API to inject a
   custom `Font` into the system-drawn title. The standard workaround,
   already precedented by `MenuView.swift:178-179`
   (`.navigationTitle("")` + `.navigationBarTitleDisplayMode(.inline)`), is
   to pair that with a `.toolbar { ToolbarItem(placement: .principal) { ... } }`
   holding a styled `Text`.

## 4. Architecture

### 4.1 Theme → Font mapping (`BrandFont.swift`, App target)

Add one helper alongside the existing `.zen`/`.doom` statics:

```swift
static func themed(_ theme: Theme, size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
    theme == .doom ? doom(size: size, relativeTo: textStyle) : zen(size: size, relativeTo: textStyle)
}
```

This is the only new API surface. Every reactive call site below uses it
instead of writing the `theme == .doom ? ... : ...` ternary inline.

### 4.2 Level-clear celebration (theme-reactive)

`LevelClearView` ([`LevelClearView.swift`](../../../App/ZenWordOfDoom/LevelClearView.swift))
gains a `theme: Theme` stored property, passed in from its one construction
site at `GameContainerView.swift:227`, which already has
`levelService.theme(forID: level.id)` in scope (computed a few lines above,
at line 204, for `SceneRevealView`).

Only the `"Level Cleared"` text (line 28) changes, from
`.font(.title2.weight(.bold))` to `.font(BrandFont.themed(theme, size: 24, relativeTo: .title2))`.
Score, "points", the serenity line, and "NEW CREATURE"/creature-name all stay
exactly as they are — those are data readouts, not a headline.

### 4.3 Pack banners (theme-reactive)

`PackBannerView` ([`MetaViews.swift:41-`](../../../App/ZenWordOfDoom/MetaViews.swift))
gains a `theme: Theme` stored property, passed in from its one construction
site at `GameContainerView.swift:214`, using the same
`levelService.theme(forID: level.id)` value already in scope in that view.

Only `pack.name` (line 46) changes, from `.font(.title3.weight(.bold))` to
`.font(BrandFont.themed(theme, size: 20, relativeTo: .title3))`. `pack.flavor`
(the caption subtitle) is untouched.

### 4.4 Nav titles (fixed pairing, Bestiary + Shrine only)

Both screens currently end with:

```swift
.navigationTitle("Bestiary")   // or "Shrine"
.navigationBarTitleDisplayMode(.inline)
```

Both change to:

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

(Shrine: `BrandFont.zen(size: 22, relativeTo: .headline)`, text "Shrine".)

The explicit `.accessibilityLabel` guards against VoiceOver picking up
nothing (or something unexpected) once the title stops being a plain string
— worth keeping even though it repeats the literal text, since it's the
thing that makes the empty `navigationTitle("")` safe to use here.

`StatsView.swift` and `SettingsView.swift` are not touched by this spec.

Point sizes given in §4.2-4.4 (24, 20, 22) are starting values chosen to
roughly match each site's current system-font size — not hard requirements.
Tune them on-device during implementation if the brand faces read too large,
too small, or clip against surrounding chrome at accessibility Dynamic Type
sizes.

## 5. Testing

- Existing UI/snapshot-style tests, if any cover these four views, should
  keep passing — this is a font/param change, not a behavior change.
- Manual on-device verification (per this project's established pattern for
  font work): load a Zen-themed level and a Doom-themed level, confirm the
  level-clear headline and pack banner render in the matching brand face at
  a couple of Dynamic Type sizes; open Bestiary and Shrine and confirm the
  nav title renders in the fixed face and that VoiceOver announces the
  expected label.
