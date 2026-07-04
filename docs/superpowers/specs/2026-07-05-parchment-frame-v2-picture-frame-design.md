# Parchment Chrome v2: Picture-Frame Border + Solid Mat

**Status:** Design approved (brainstorm), pending implementation plan.
**Date:** 2026-07-05

## 1. Summary

Replaces the v1 parchment chrome (`docs/superpowers/specs/2026-07-04-parchment-frame-chrome-design.md`,
implemented and shipped as v0.4.6-v0.4.9) with a two-layer design: a thin
decorative **frame** ring (new agy-generated art — smooth rock-garden stones
for Zen, grey basalt with faint lava-vein cracks for Doom) around a plain
**mat** fill (a SwiftUI-drawn color/gradient, no image, no scrim). This
directly addresses the recurring failure mode from the v1 session: a single
texture tried to be both the ornamental border AND the full background fill
via `capInsets` stretching, which repeatedly produced oversized buttons that
overlapped their neighbors, washed-out text under a mis-layered scrim, and a
border that only rendered correctly on one edge. Splitting frame from fill
removes all three failure classes structurally, and lets buttons shrink back
toward their pre-parchment size since the mat no longer needs extra
clearance to coexist with a stretched border.

## 2. Goals / non-goals

**Goals**
- Same scope as v1: `ParchmentButtonStyle` (Play/Submit/Clear/hint/mic-style
  buttons) and `.parchmentReadout(theme:)` (HUD pills, doom timer, word
  ribbon, found-words tags).
- Buttons/readouts shrink back toward their pre-parchment size (~52pt for
  `.wide`/`.icon`, down from v1's ~85pt/64pt) while staying visually
  decorative.
- New art direction: Zen = smooth river-stone/rock-garden frame with a
  raked-sand mat; Doom = grey basalt/crumbling-rock frame with faint
  lava-vein cracks and an ash-grey mat with a faint ember glow. Explicitly
  **not** brown/charred for Doom — approved only after the frame was
  corrected from an early brown draft to cool grey.
- No scrim. The mat is a real, opaque (or the app's own accessibility
  translucency rules) SwiftUI fill — contrast is inherent to the fill/ink
  pair, not composited at runtime.

**Non-goals**
- No change to which call sites are in/out of scope — identical list to v1
  section 3 (`docs/superpowers/specs/2026-07-04-parchment-frame-chrome-design.md`).
- No change to the Shrine cosmetics system — still a global reskin, not a
  new unlockable palette (re-confirmed implicitly by not being raised this
  round; v1's non-goal stands).
- Not attempting to reuse or repair the v1 `frame-*` textures — they're
  full-fill textures with the wrong internal structure (no transparent
  center) for this design and are fully replaced.

## 3. What breaks from v1 and why

Three concrete bugs shipped and were fixed reactively in v1 (v0.4.6-v0.4.9),
all stemming from the same root design flaw:

1. **Oversized buttons overlapping neighbors.** `Image.resizable(capInsets:)`
   enforces a hard minimum size equal to the sum of the insets, and
   `.background()` never lets a background's size affect the primary view.
   A capInset large enough to show the v1 art's ornamental corners exceeded
   real button content height, so the background rendered oversized and
   painted over the next sibling.
2. **Text washed out under the scrim.** An `.overlay`-based scrim paints in
   front of everything, including the label — a structural hazard any time
   a scrim needs to sit *behind* text but *in front of* a background image.
3. **Missing bottom border.** The generated PNG's transparent margin was
   asymmetric (top flush, bottom padded), so a symmetric capInset captured
   real art on top and empty transparency on the bottom.

All three are consequences of one texture serving two incompatible jobs.
Splitting frame (thin, fixed-purpose ring) from mat (plain fill, no
capInsets stretching at all) removes the shared failure surface rather than
patching each symptom.

## 4. Asset plan

Same 3 shapes × 2 themes = 6 textures, same naming as v1
(`frame-{zen,doom}-{button,icon,strip}`) — the v2 generation script
overwrites these exact imageset paths in place (no old-vs-new coexistence,
no rename); the v1 art is fully discarded, not kept as a fallback —
restructured:

- **Transparent center.** Only the outer ring (~15-20% of each dimension,
  exact proportion tuned per shape during generation) is opaque; the middle
  is fully transparent so the SwiftUI-drawn mat shows through untouched.
- **Zen art direction:** smooth, rounded river stones forming the ring,
  pale grey/tan tones, calm and orderly (matches the rock-garden aesthetic
  already used in this app's background art).
- **Doom art direction:** grey basalt/volcanic rock forming the ring, with
  *faint* lava-vein cracks (thin, low-opacity warm streaks — not bold bright
  lines; an early draft with strong orange cracks was explicitly rejected
  during mockup review). Cool grey base, not brown/charred.
- **CapInsets:** measured from each generated PNG's actual alpha channel
  after generation (never guessed up front — this was the single most
  expensive lesson from v1, where guessed insets required three separate
  correction passes). Expected to be small and safe by construction, since
  the ring's own thickness defines the cap and there's no competing "must
  also serve as a fill" requirement pushing it larger.

## 5. Mat fill (replaces the scrim)

No image, no runtime compositing. A plain SwiftUI fill drawn directly behind
the label, sized to the button/pill's real content — the same shape/sizing
role `AccessibilityPalette.parchmentScrim(for:)` played in v1, but opaque
and structural rather than a translucent overlay:

- **Zen mat:** warm sand/cream base with a subtle raked-line pattern (a
  low-contrast repeating diagonal `LinearGradient`, matching the mockup) —
  decorative texture with zero risk of the v1 texture-vs-scrim blending
  problem, since it's one flat paint operation, not two layers trying to
  show through each other.
- **Doom mat:** dark ash-grey base with a faint warm radial glow near one
  edge (a single low-opacity `RadialGradient`, matching the mockup).
- **Ink colors:** new fixed constants (analogous to v1's
  `parchmentInkZen`/`parchmentInkDoom`), chosen against the new mat base
  colors and pinned by a WCAG-AA contrast test — replacing
  `parchmentScrimZen`/`parchmentScrimDoom` entirely (no scrim constants
  survive into v2).

## 6. Sizing

- `.wide` / `.icon` buttons: padding shrinks back toward pre-parchment
  values (roughly the ~44pt-ish floor plus a small comfortable margin,
  landing near the mockup's 52pt) now that the mat doesn't need to
  co-exist with a stretched border inside the same space.
- Menu button `VStack` spacing can revert from v1's compressed 8pt back
  toward the original 16pt, since buttons are compact again.
- `.strip` readouts tighten proportionally (exact values during
  implementation, following the same "measure, don't guess" discipline as
  the frame capInsets).

## 7. Testing

- New pinned contrast test(s) for each mat/ink pair (mirrors
  `WCAGContrastTests.testParchmentPairsMeetAA`, replacing it rather than
  adding alongside it — the old scrim constants are gone).
- Asset-existence test updated for the (same-named, restructured) 6
  textures — mirrors `ParchmentChromeTests.testAllFrameTexturesExistInBundle`.
- `AccessibilityAuditTests` must keep passing unmodified — 44×44pt touch
  targets are preserved via padding regardless of the visual size decrease.
- Manual on-device check at default AND an accessibility Dynamic Type size
  (e.g. AX3/AXXL) for both themes — v1 shipped multiple regressions that
  only appeared in one specific size/theme combination, so this check
  explicitly covers the matrix, not just one configuration.
