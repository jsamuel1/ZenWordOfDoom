# Zen Word of Doom

A meditative word puzzle for iPhone with a dark secret. Spin letters from a
wheel to build words and complete a crossword grid, while serene Zen
backgrounds slowly reveal the Doom-like creatures hidden within them.

> **Calm on the surface. Something is watching underneath.**

## The Pitch

Zen Word of Doom is an **anagram-crossword hybrid**. Each level gives you a
small set of letters arranged on a circular wheel. Trace, tap, or *speak*
words built from those letters. Valid words fill into a crossword-style grid.
Clear the grid to advance.

The twist is atmospheric: every level is a tranquil Zen scene — raked sand,
still water, bamboo, lantern light. But concealed in each background is a
hidden creature straight out of a Doom-like bestiary. The calmer you stay and
the more words you find, the more the scene shifts and the creatures stir.

## Core Mechanics

- **Letter wheel** of 5–9 unique letters. Each letter may be used **once per
  word**.
- Build words of length **3 to N** (N = number of letters on the wheel).
- Found words drop into a **crossword grid** of interlocking slots.
- **Three input methods**, fully interchangeable:
  1. **Swipe** — drag a finger across letters to chain them.
  2. **Tap** — tap letters in sequence.
  3. **Voice** — speak the word; on-device speech recognition matches it.
- Difficulty scales by wheel size: **5 letters (easy) → 9 letters (max)**.

## Status

📋 **Specification phase.** No application code yet. This repository currently
contains the full design and technical specification.

| Document | Purpose |
| --- | --- |
| [`docs/SPEC.md`](docs/SPEC.md) | Game design + functional specification |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Technical architecture, modules, data flow |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Milestones and delivery plan |

## Tech Stack (proposed)

- **Swift 5.9+ / iOS 17+**
- **SwiftUI** for chrome, menus, and HUD
- **SpriteKit** for the wheel, word-trace overlay, grid, and animated scenes
- **Speech** framework for on-device voice input
- **Swift Package Manager** for dependencies and modularization

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the rationale.

## License

Apache License 2.0 — see [`LICENSE`](LICENSE).
