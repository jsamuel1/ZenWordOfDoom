# Zen Word of Doom — Roadmap

Milestone plan for taking the spec to a shippable v1. Each milestone is a
demonstrable slice; earlier ones are mostly pure-Swift and unit-testable.

---

## M0 — Project scaffolding
- Xcode project + SPM package targets per [`ARCHITECTURE.md`](ARCHITECTURE.md).
- CI: build + unit tests (works toward a SessionStart hook for web sessions).
- Apache-2.0 headers, app icon placeholder, launch screen.

**Exit:** empty app launches; all packages build; test target runs.

---

## M1 — Word-game core (headless)
- `GameCore` models: Wheel, Grid, Level, submission pipeline, scoring.
- `WordEngine`: bundle a curated word list, build DAWG, `contains` +
  `canBuild` + sub-anagram search.
- `LevelKit`: JSON level format + loader + validation invariants.
- Full unit-test coverage of rules.

**Exit:** given a level JSON + a sequence of words, the engine correctly fills
the grid, awards bonus words, and rejects invalids — proven by tests, no UI.

---

## M2 — Playable wheel + grid (swipe & tap)
- `SceneKitFX`: render the letter wheel, the forming-word ribbon, and the
  crossword grid in SpriteKit via `SpriteView`.
- `InputKit`: swipe (drag-to-connect) and tap input → submission pipeline.
- Wire SwiftUI shell: level select → play → complete.
- Shuffle, clear/backspace, found-words tray.

**Exit:** a person can play a level end-to-end with swipe or tap on device.

---

## M3 — Zen/Doom scenes + reveal engine
- Author 1–2 Zen scenes with hidden creatures.
- `RevealController` + `stir`-driven shader/mask reveal; the held
  completion beat and calming exhale.
- `Audio`: ambient bus + reactive Doom bus tracking `stir`.
- Reduced-Doom / reduced-motion settings.

**Exit:** finding words visibly stirs the scene; clearing reveals the creature
then calms; accessibility toggles work.

---

## M4 — Voice input
- `VoiceKit`: permission flow, on-device `SFSpeechRecognizer`, candidate
  resolution → tile sequence → submission pipeline.
- In-context mic permission explainer; graceful fallback when unsupported.

**Exit:** speaking a valid word fills the grid exactly like swipe/tap.

---

## M5 — Progression & meta
- `Persistence` (SwiftData): profile, level progress, bestiary, stats.
- Serenity currency, hints, scene unlocks.
- Level packs, difficulty ramp 5→9 letters, daily puzzle, Doom mode (timer).
- Bestiary gallery.

**Exit:** a player can progress across packs, earn/spend serenity, collect
creatures, and play the daily.

---

## M6 — Content, polish, ship
- Full level content pass + generator-assisted authoring; validate every level.
- Art/audio polish, haptics, onboarding/tutorial.
- Accessibility audit (VoiceOver, Dynamic Type, contrast).
- App Store assets, privacy nutrition labels (mic/speech on-device),
  age-rating review.

**Exit:** submission-ready build.

---

## Cross-cutting / ongoing
- Keep `GameCore` and `WordEngine` UI-free and fully tested.
- Every bundled level must pass validation invariants in CI.
- Confirm word-list license before M1 ships (see SPEC §13).
- Decide monetization model before M5 (premium vs. cosmetic IAP; no ads).
