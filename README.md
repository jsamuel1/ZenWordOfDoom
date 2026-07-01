# Zen Word of Doom

A meditative word puzzle for iPhone with a dark secret. Spin letters from a
wheel to build words and complete a crossword grid, while serene Zen
backgrounds slowly reveal the Doom-like creatures hidden within them.

> **Calm on the surface. Something is watching underneath.**

## The game

Zen Word of Doom is an **anagram-crossword hybrid**. Each level gives you a
small set of letters on a circular wheel. Trace, tap, or *speak* words built
from those letters; valid words fill an interlocking crossword grid. Clear the
grid to advance.

The twist is atmospheric: every level is a tranquil Zen scene, but concealed in
it is a creature from a Doom-like bestiary. A per-level **"stir" meter** rises
as you find words — the palette darkens, shadows deepen, and the hidden creature
surfaces, fully revealing for a held beat when you clear the grid before the
scene exhales back to calm. Between levels, a short **cut scene** ("breath")
plays a moving scene and a twisted-Zen poem. The theme permanently swaps between
**Zen-with-Doom** and **Doom-with-Zen** each time you cross a **prime-numbered
level**.

**Core mechanics**

- **Letter wheel** of 5–9 letters; each letter is used at most once per word.
- Words of length **3 to N** (N = wheel size); found words drop into the grid.
- **Three interchangeable inputs:** swipe (drag across letters), tap, and
  **voice** (on-device speech recognition).
- Difficulty scales with wheel size (5 letters → 9), escalating as you progress.
- Linear unlock, per-level best scores, a **bestiary** of revealed creatures,
  and accessibility options (**Reduced Doom**, reduced motion).

### How levels are made

Levels are **procedurally generated and deterministic** — a given level id
always yields the same puzzle, so progression stays stable across devices and
launches. From a seed `(theme, band, index)` the generator derives the wheel, a
themed word pool, an interlocking crossword layout, and a scene/creature.

Every word that can appear is a **real word from the game's bundled main
corpus** (the public-domain [ENABLE] list, `GeneralWordList`), biased toward
on-theme (Zen/Doom lexicon) and common words so grids read naturally. At play
time, typed *bonus* words are additionally validated against the iOS system
dictionary (`UITextChecker`); grid answers are authoritative (already corpus
words) and always accepted.

On **Apple-Intelligence** devices the word pool and the scene/creature art are
enriched **on-device at runtime** — iOS 26 **Foundation Models** proposes themed
words (hard-filtered to real, buildable, main-corpus words) and **Image
Playground** generates themed illustrations. Every one of these has a
deterministic/bundled fallback, so the game is fully playable — and looks
complete — on every device, in CI, and in the simulator, with no network calls.

## Project layout

Pure, headless-testable Swift lives in SPM packages (`Sources/`, `Tests/`); the
iOS-only code (SwiftUI, the procedural `Canvas` scenes, and the Apple frameworks
that need a device) lives in the app target (`App/ZenWordOfDoom/`).

```
Sources/
  GameCore/     Pure rules & models: wheel, grid, submission pipeline, scoring, RNG
  WordEngine/   Word list / anagram support used for authoring & tests
  LevelGen/     Procedural generation: corpus, theme lexicons, wheel/word/grid/scene
                pickers, ProceduralLevelLibrary, Primes, prompt text — all deterministic
  LevelKit/     Between-levels cut-scene data
App/ZenWordOfDoom/
  SwiftUI views (menu, game, grid, wheel, HUD, bestiary, cut scene, settings)
  LevelService              async level resolution + play order (injected)
  FoundationModelsWordProvider / WordPoolCache   on-device LLM word pool (iOS-only)
  ImagePlaygroundVisualProvider / VisualCache / BundledVisuals   on-device + bundled art
  SystemDictionary          UITextChecker word validation
  VoiceInput                on-device speech recognition
docs/            SPEC.md, ARCHITECTURE.md, ROADMAP.md, CI.md, and design docs
project.yml      XcodeGen spec (the .xcodeproj is generated, not committed)
```

The app target depends on the packages; the packages never depend on the app.
iOS-only capabilities are reached through protocol **seams** so the pure core
stays platform-agnostic and testable: `ThemedWordProvider` (word source),
`SceneVisualProvider` (images), and `WordValidating` (dictionary).

## Building & running

You need a full **Xcode** install (the iOS 26.5 SDK) and
[XcodeGen](https://github.com/yonwoo9/XcodeGen). The `.xcodeproj` is **not
committed** — it is generated from `project.yml`, so generate it first:

```sh
brew install xcodegen
xcodegen generate
open ZenWordOfDoom.xcodeproj      # then build/run the ZenWordOfDoom scheme
```

Re-run `xcodegen generate` whenever you change `project.yml` or add/remove app
source files.

**Testing the packages** (no simulator needed):

```sh
swift test
```

> `swift test` needs a full Xcode toolchain for XCTest — the bare Command Line
> Tools won't work. If `swift test` can't find XCTest, point it at Xcode:
> `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
> (use your Xcode path; a beta lives under `Xcode-beta.app`).

**On-device AI features** (Foundation Models word generation, Image Playground
art) only activate on Apple-Intelligence-capable hardware with the feature
enabled. On the simulator and other devices they degrade to the deterministic
word generator and bundled/procedural art — expected and correct.

## CI & releases

Two systems, split by concern (details in [`docs/CI.md`](docs/CI.md)):

- **GitHub Actions** ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) —
  runs on every push and PR (`macos-26`): `swift test` on the pure packages, and
  an XcodeGen-generate + simulator build of the app. This is the fast
  correctness gate; it does no signing.
- **Xcode Cloud** — produces **signed TestFlight** builds on **`v*` tags**. Its
  post-clone step ([`ci_scripts/ci_post_clone.sh`](ci_scripts/ci_post_clone.sh))
  installs XcodeGen and generates the project (since the `.xcodeproj` isn't in
  the repo), then archives and delivers to internal testers.

**Cutting a release:** bump the version, tag, and push the tag — the tag is what
triggers the Xcode Cloud → TestFlight pipeline.

```sh
scripts/bump-version.sh [patch|minor|major]   # defaults to patch; edits project.yml
git commit -am "Release vX.Y.Z"
git tag vX.Y.Z && git push --follow-tags
```

`bump-version.sh` bumps both `MARKETING_VERSION` (X.Y.Z) and
`CURRENT_PROJECT_VERSION` (the build number — TestFlight rejects re-used builds).

## Adding & modifying features

1. **Put logic where it can be tested.** Anything that doesn't need UIKit /
   Foundation Models / Image Playground / `UITextChecker` belongs in a package
   (`GameCore`, `LevelGen`, …) with unit tests. iOS-only code goes in the app
   target, ideally behind one of the protocol seams above so a pure/mock
   implementation exists for tests and fallback.
2. **Keep generation deterministic.** `LevelGen` output must stay reproducible
   from `(theme, band, index)` so level ids remain stable (saved progress is
   keyed by id). Non-deterministic sources (Foundation Models) are enrichment on
   top of a deterministic floor, cached per level.
3. **Work test-first.** Add/adjust a package test, watch it fail, implement, and
   keep the full suite green (`swift test`). Verify app-target changes by
   building the `ZenWordOfDoom` scheme for a simulator.
4. **Design docs.** Larger features are specced and planned under
   [`docs/superpowers/`](docs/superpowers/) (specs → plans); the game and
   technical designs live in [`docs/SPEC.md`](docs/SPEC.md) and
   [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). Update the relevant doc when
   you change behavior.
5. **Assets.** The app icon and menu **title art** are curated static
   illustrations in `Assets.xcassets` (see [`docs/SPEC.md`](docs/SPEC.md) §6.5);
   in-game scene/creature art is generated on-device (or the bundled fallback in
   `Assets.xcassets`, keyed by the slug lists in `BundledVisuals.swift` /
   `VisualPrompts.swift` — keep those in sync when adding a slug).

## Tech stack

- **Swift 5.9+ / iOS 26.5** (app target; the pure-Swift cores build for iOS 17+)
- **SwiftUI** for all UI and the procedural (`Canvas`) scenes and reveal effects
- **Foundation Models** (on-device LLM) for themed word generation
- **Image Playground** (`ImageCreator`) for on-device scene/creature art
- **Speech** for on-device voice input; **`UITextChecker`** for word validation
- **Swift Package Manager** for the modular cores; **XcodeGen** for the project

## License

Apache License 2.0 — see [`LICENSE`](LICENSE).

[ENABLE]: https://en.wikipedia.org/wiki/Enhanced_North_American_Benchmark_Lexicon
