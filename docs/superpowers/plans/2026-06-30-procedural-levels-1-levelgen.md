# LevelGen Package Implementation Plan (Phase 1 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a pure-Swift `LevelGen` package that deterministically generates solvable, themed (Zen/Doom) crossword `Level`s from a seed — no Foundation Models, no UIKit.

**Architecture:** A new SwiftPM library target `LevelGen` depending on `GameCore`. It bundles curated all-real themed word lists, picks a seeded wheel from a base word, finds buildable words, interlocks them into a crossword via a greedy seeded layout engine, and assigns a seeded scene/creature. Everything is deterministic and headlessly unit-tested. App wiring/migration and FM integration are later plans.

**Tech Stack:** Swift 5.9, SwiftPM, XCTest. Reuses `GameCore` (`Wheel`, `GridSlot`, `Level`, `LetterMultiset`, `SeededRandom`, `DifficultyBand`).

**Spec:** `docs/superpowers/specs/2026-06-30-procedural-level-generation-design.md`

---

## File Structure

- `Package.swift` — add `LevelGen` library target (+ resources) and `LevelGenTests` test target.
- `Sources/LevelGen/Theme.swift` — `Theme` enum.
- `Sources/LevelGen/Resources/seed-zen.txt`, `seed-doom.txt` — newline word lists (all real words).
- `Sources/LevelGen/ThemedSeedList.swift` — loads/serves seed words per theme.
- `Sources/LevelGen/WheelPicker.swift` — seeded base-word → `Wheel`.
- `Sources/LevelGen/SeedListWordProvider.swift` — buildable-word search over the seed list.
- `Sources/LevelGen/CrosswordLayoutEngine.swift` — greedy seeded interlock → `[GridSlot]`.
- `Sources/LevelGen/SceneCreaturePicker.swift` — seeded scene/creature ids per theme.
- `Sources/LevelGen/LevelSeed.swift` — `LevelSeed` (theme, band, index) + stable id.
- `Sources/LevelGen/ProceduralGenerator.swift` — ties the pieces into a `Level`.
- `Sources/LevelGen/ProceduralLevelLibrary.swift` — ordered seeded id sequence + lookup.
- `Tests/LevelGenTests/*` — one test file per component.

---

### Task 1: Add the LevelGen package target

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: Add the library product, target, and test target**

In `Package.swift`, add to `products`:
```swift
.library(name: "LevelGen", targets: ["LevelGen"]),
```
Add to `targets` (after `LevelKit`):
```swift
.target(
    name: "LevelGen",
    dependencies: ["GameCore"],
    resources: [.process("Resources")]
),
.testTarget(name: "LevelGenTests", dependencies: ["LevelGen", "GameCore"]),
```

- [ ] **Step 2: Create a placeholder resource so the target builds**

Create `Sources/LevelGen/Resources/seed-zen.txt` with one word:
```
CALM
```
Create `Sources/LevelGen/Resources/seed-doom.txt` with one word:
```
DREAD
```

- [ ] **Step 3: Verify the package resolves and builds**

Run: `swift build`
Expected: builds with the new `LevelGen` target (no sources yet is fine; SwiftPM allows an empty target with resources only once a `.swift` file exists — add `Theme.swift` next).

- [ ] **Step 4: Commit**

```bash
git add Package.swift Sources/LevelGen/Resources
git commit -m "build: add LevelGen package target"
```

---

### Task 2: Theme enum

**Files:**
- Create: `Sources/LevelGen/Theme.swift`
- Test: `Tests/LevelGenTests/ThemeTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import LevelGen

final class ThemeTests: XCTestCase {
    func test_themes_areStableRawValues() {
        XCTAssertEqual(Theme.zen.rawValue, "zen")
        XCTAssertEqual(Theme.doom.rawValue, "doom")
        XCTAssertEqual(Theme.allCases.count, 2)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ThemeTests`
Expected: FAIL — `Theme` not found.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

public enum Theme: String, CaseIterable, Codable, Sendable {
    case zen
    case doom
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ThemeTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/LevelGen/Theme.swift Tests/LevelGenTests/ThemeTests.swift
git commit -m "feat(levelgen): add Theme enum"
```

---

### Task 3: Themed seed word lists + loader

**Files:**
- Modify: `Sources/LevelGen/Resources/seed-zen.txt`, `seed-doom.txt`
- Create: `Sources/LevelGen/ThemedSeedList.swift`
- Test: `Tests/LevelGenTests/ThemedSeedListTests.swift`

- [ ] **Step 1: Populate the seed lists with real themed words**

Replace `seed-zen.txt` with (one word per line, uppercase, all real dictionary words; include lengths 5–9 so wheels can be picked, plus shorter sub-words):
```
CALM
STILL
LOTUS
BREATH
GRACE
SERENE
GARDEN
STREAM
TEMPLE
PEACE
MIND
FLOW
STONE
RIVER
BLOOM
PETAL
SHRINE
QUIET
GENTLE
EMBER
```

Replace `seed-doom.txt` with:
```
DREAD
SHADOW
CRYPT
ABYSS
ELDER
FIEND
SPECTER
GRAVE
SLAYER
STAKE
WRAITH
OMEN
TOMB
HEXED
GHOUL
PLAGUE
CURSE
DEMON
NIGHT
BLOOD
```

(These are starter lists; they can be expanded later. Tests assert format + buildability, not a fixed count.)

- [ ] **Step 2: Write the failing test**

```swift
import XCTest
@testable import LevelGen

final class ThemedSeedListTests: XCTestCase {
    func test_loadsNonEmptyUppercaseAlphaWords_perTheme() {
        for theme in Theme.allCases {
            let words = ThemedSeedList.shared.words(for: theme)
            XCTAssertFalse(words.isEmpty, "\(theme) seed list is empty")
            for w in words {
                XCTAssertEqual(w, w.uppercased(), "\(w) not uppercase")
                XCTAssertTrue(w.allSatisfy(\.isLetter), "\(w) has non-letters")
                XCTAssertGreaterThanOrEqual(w.count, 3, "\(w) too short")
            }
        }
    }

    func test_hasBaseWordsForEveryBandLength() {
        // Need at least one word of each wheel length 5...9 per theme.
        for theme in Theme.allCases {
            let lengths = Set(ThemedSeedList.shared.words(for: theme).map(\.count))
            for n in 5...9 {
                XCTAssertTrue(lengths.contains(n), "\(theme) missing a length-\(n) base word")
            }
        }
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `swift test --filter ThemedSeedListTests`
Expected: FAIL — `ThemedSeedList` not found.

- [ ] **Step 4: Write minimal implementation**

```swift
import Foundation

/// Loads the bundled, curated all-real themed word lists.
public struct ThemedSeedList: Sendable {
    public static let shared = ThemedSeedList()

    private let byTheme: [Theme: [String]]

    public init() {
        var map: [Theme: [String]] = [:]
        for theme in Theme.allCases {
            map[theme] = Self.load(resource: "seed-\(theme.rawValue)")
        }
        self.byTheme = map
    }

    public func words(for theme: Theme) -> [String] { byTheme[theme] ?? [] }

    private static func load(resource: String) -> [String] {
        guard let url = Bundle.module.url(forResource: resource, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter ThemedSeedListTests`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Sources/LevelGen/ThemedSeedList.swift Sources/LevelGen/Resources Tests/LevelGenTests/ThemedSeedListTests.swift
git commit -m "feat(levelgen): bundle themed seed lists with loader"
```

---

### Task 4: WheelPicker — seeded base word → Wheel

**Files:**
- Create: `Sources/LevelGen/WheelPicker.swift`
- Test: `Tests/LevelGenTests/WheelPickerTests.swift`

The band's target wheel length: easy=5, medium=6, hard=7, expert=8, master=9.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import GameCore
@testable import LevelGen

final class WheelPickerTests: XCTestCase {
    func test_wheelLengthMatchesBand() {
        let cases: [(DifficultyBand, Int)] = [
            (.easy, 5), (.medium, 6), (.hard, 7), (.expert, 8), (.master, 9)
        ]
        for (band, n) in cases {
            let wheel = WheelPicker.wheel(theme: .zen, band: band, index: 0)
            XCTAssertEqual(wheel.size, n, "band \(band) → \(wheel.size), expected \(n)")
        }
    }

    func test_isDeterministic() {
        let a = WheelPicker.wheel(theme: .doom, band: .hard, index: 3)
        let b = WheelPicker.wheel(theme: .doom, band: .hard, index: 3)
        XCTAssertEqual(a.tiles.map(\.letter), b.tiles.map(\.letter))
    }

    func test_baseWordComesFromSeedList() {
        let wheel = WheelPicker.wheel(theme: .zen, band: .hard, index: 1)
        let letters = String(wheel.tiles.map(\.letter))
        let candidates = ThemedSeedList.shared.words(for: .zen).filter { $0.count == 7 }
        XCTAssertTrue(candidates.contains(letters), "\(letters) not a length-7 zen seed word")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter WheelPickerTests`
Expected: FAIL — `WheelPicker` not found.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation
import GameCore

public enum WheelPicker {
    /// Target wheel length (max word length) for a band.
    public static func wheelLength(for band: DifficultyBand) -> Int {
        switch band {
        case .easy: return 5
        case .medium: return 6
        case .hard: return 7
        case .expert: return 8
        case .master: return 9
        }
    }

    /// Deterministically pick a themed base word of the band's length; its
    /// letters form the wheel.
    public static func wheel(theme: Theme, band: DifficultyBand, index: Int) -> Wheel {
        let n = wheelLength(for: band)
        let candidates = ThemedSeedList.shared.words(for: theme)
            .filter { $0.count == n }
            .sorted() // stable order independent of file order
        precondition(!candidates.isEmpty, "no length-\(n) \(theme) base word")
        var rng = SeededRandom(seed: seed(theme: theme, band: band, index: index))
        let pick = candidates[Int(rng.next() % UInt64(candidates.count))]
        return Wheel(letters: pick)
    }

    static func seed(theme: Theme, band: DifficultyBand, index: Int) -> UInt64 {
        var h: UInt64 = 1469598103934665603 // FNV offset
        for s in [theme.rawValue, band.rawValue, "\(index)"] {
            for b in s.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        }
        return h
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter WheelPickerTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/LevelGen/WheelPicker.swift Tests/LevelGenTests/WheelPickerTests.swift
git commit -m "feat(levelgen): seeded WheelPicker from themed base words"
```

---

### Task 5: SeedListWordProvider — buildable themed words

**Files:**
- Create: `Sources/LevelGen/ThemedWordProvider.swift` (protocol)
- Create: `Sources/LevelGen/SeedListWordProvider.swift`
- Test: `Tests/LevelGenTests/SeedListWordProviderTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import GameCore
@testable import LevelGen

final class SeedListWordProviderTests: XCTestCase {
    func test_returnsOnlyBuildableSeedWords() {
        let wheel = Wheel(letters: "GARDEN") // medium
        let provider = SeedListWordProvider()
        let words = provider.words(forWheel: wheel, theme: .zen, limit: 50)
        let multiset = wheel.multiset
        for w in words {
            XCTAssertTrue(multiset.canBuild(w), "\(w) not buildable from GARDEN")
            XCTAssertTrue(ThemedSeedList.shared.words(for: .zen).contains(w))
            XCTAssertGreaterThanOrEqual(w.count, 3)
        }
    }

    func test_isDeterministicAndRespectsLimit() {
        let wheel = Wheel(letters: "SHADOW")
        let p = SeedListWordProvider()
        let a = p.words(forWheel: wheel, theme: .doom, limit: 5)
        let b = p.words(forWheel: wheel, theme: .doom, limit: 5)
        XCTAssertEqual(a, b)
        XCTAssertLessThanOrEqual(a.count, 5)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SeedListWordProviderTests`
Expected: FAIL — types not found.

- [ ] **Step 3: Write the protocol**

`Sources/LevelGen/ThemedWordProvider.swift`:
```swift
import GameCore

/// Supplies candidate themed words for a wheel. Implementations may be
/// deterministic (seed list) or generative (Foundation Models, later phase).
public protocol ThemedWordProvider: Sendable {
    func words(forWheel wheel: Wheel, theme: Theme, limit: Int) -> [String]
}
```

- [ ] **Step 4: Write the implementation**

`Sources/LevelGen/SeedListWordProvider.swift`:
```swift
import Foundation
import GameCore

/// Deterministic provider: every buildable seed word for the wheel, longest
/// first (ties broken alphabetically), capped at `limit`.
public struct SeedListWordProvider: ThemedWordProvider {
    private let minLength: Int
    public init(minLength: Int = 3) { self.minLength = minLength }

    public func words(forWheel wheel: Wheel, theme: Theme, limit: Int) -> [String] {
        let multiset = wheel.multiset
        return ThemedSeedList.shared.words(for: theme)
            .filter { $0.count >= minLength && multiset.canBuild($0) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0 < $1 }
            .prefix(limit)
            .map { $0 }
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter SeedListWordProviderTests`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Sources/LevelGen/ThemedWordProvider.swift Sources/LevelGen/SeedListWordProvider.swift Tests/LevelGenTests/SeedListWordProviderTests.swift
git commit -m "feat(levelgen): ThemedWordProvider protocol + seed-list provider"
```

---

### Task 6: CrosswordLayoutEngine — greedy seeded interlock

**Files:**
- Create: `Sources/LevelGen/CrosswordLayoutEngine.swift`
- Test: `Tests/LevelGenTests/CrosswordLayoutEngineTests.swift`

Algorithm: place the longest word across at the origin; for each remaining word, find every placement that crosses an existing letter (perpendicular), is conflict-free (overlaps only on equal letters), keeps word ends and non-crossing neighbors clear so words never run together; pick one deterministically; stop at `maxSlots`. Normalize coordinates to non-negative.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import GameCore
@testable import LevelGen

final class CrosswordLayoutEngineTests: XCTestCase {
    private func cellMap(_ slots: [GridSlot]) -> [GridCoord: Character] {
        var m: [GridCoord: Character] = [:]
        for slot in slots {
            for (i, cell) in slot.cells.enumerated() {
                m[cell] = Array(slot.answer)[i]
            }
        }
        return m
    }

    func test_allCrossingsAgree_andCoordsNonNegative() {
        let words = ["GARDEN", "RANGE", "DEAR", "READ", "GEAR", "DEAN", "NEAR"]
        let slots = CrosswordLayoutEngine().layout(words: words, maxSlots: 6, seed: 42)
        XCTAssertFalse(slots.isEmpty)
        // Build cells, asserting overlaps are consistent (no conflict).
        var m: [GridCoord: Character] = [:]
        for slot in slots {
            let chars = Array(slot.answer)
            for (i, cell) in slot.cells.enumerated() {
                if let existing = m[cell] {
                    XCTAssertEqual(existing, chars[i], "conflict at \(cell)")
                } else {
                    m[cell] = chars[i]
                }
                XCTAssertGreaterThanOrEqual(cell.row, 0)
                XCTAssertGreaterThanOrEqual(cell.col, 0)
            }
        }
    }

    func test_isConnected() {
        let words = ["GARDEN", "RANGE", "DEAR", "READ", "GEAR"]
        let slots = CrosswordLayoutEngine().layout(words: words, maxSlots: 5, seed: 1)
        // Every slot after the first must share at least one cell with another.
        let maps = slots.map { Set($0.cells) }
        for (i, cells) in maps.enumerated() where slots.count > 1 {
            let others = maps.enumerated().filter { $0.offset != i }.map(\.element)
            XCTAssertTrue(others.contains { !$0.isDisjoint(with: cells) },
                          "slot \(i) is disconnected")
        }
    }

    func test_isDeterministic() {
        let words = ["SHADOW", "SHADE", "HEADS", "AHEAD", "HATE"]
        let a = CrosswordLayoutEngine().layout(words: words, maxSlots: 5, seed: 7)
        let b = CrosswordLayoutEngine().layout(words: words, maxSlots: 5, seed: 7)
        XCTAssertEqual(a.map { [$0.answer, "\($0.origin.row),\($0.origin.col)", $0.direction.rawValue] },
                       b.map { [$0.answer, "\($0.origin.row),\($0.origin.col)", $0.direction.rawValue] })
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CrosswordLayoutEngineTests`
Expected: FAIL — `CrosswordLayoutEngine` not found.

- [ ] **Step 3: Write the implementation**

```swift
import Foundation
import GameCore

/// Greedy, seeded crossword layout. Produces a connected, conflict-free set of
/// interlocking slots. Words that cannot be placed are skipped.
public struct CrosswordLayoutEngine {
    public init() {}

    private struct Placement {
        let answer: String
        let origin: GridCoord
        let direction: Direction
        var cells: [GridCoord] {
            (0..<answer.count).map { o in
                direction == .across
                    ? GridCoord(row: origin.row, col: origin.col + o)
                    : GridCoord(row: origin.row + o, col: origin.col)
            }
        }
    }

    public func layout(words rawWords: [String], maxSlots: Int, seed: UInt64) -> [GridSlot] {
        let words = rawWords
            .map { $0.uppercased() }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0 < $1 }
        guard let first = words.first else { return [] }

        var rng = SeededRandom(seed: seed)
        var placed: [Placement] = [Placement(answer: first, origin: GridCoord(row: 0, col: 0), direction: .across)]
        var occupied: [GridCoord: Character] = [:]
        for (i, c) in Array(first).enumerated() {
            occupied[GridCoord(row: 0, col: i)] = c
        }

        for word in words.dropFirst() {
            if placed.count >= maxSlots { break }
            let options = placements(for: word, given: occupied)
            guard !options.isEmpty else { continue }
            let choice = options[Int(rng.next() % UInt64(options.count))]
            placed.append(choice)
            for (i, c) in Array(word).enumerated() { occupied[choice.cells[i]] = c }
        }

        return normalize(placed)
    }

    /// All valid placements crossing an existing letter.
    private func placements(for word: String, given occupied: [GridCoord: Character]) -> [Placement] {
        var result: [Placement] = []
        let chars = Array(word)
        for (cell, letter) in occupied {
            for (i, c) in chars.enumerated() where c == letter {
                for dir in [Direction.across, Direction.down] {
                    let origin = dir == .across
                        ? GridCoord(row: cell.row, col: cell.col - i)
                        : GridCoord(row: cell.row - i, col: cell.col)
                    let p = Placement(answer: word, origin: origin, direction: dir)
                    if isValid(p, given: occupied) { result.append(p) }
                }
            }
        }
        // Deterministic order before the rng picks one.
        return result.sorted {
            ($0.origin.row, $0.origin.col, $0.direction.rawValue)
                < ($1.origin.row, $1.origin.col, $1.direction.rawValue)
        }
    }

    /// Valid iff: overlaps only on equal letters; at least one real crossing;
    /// the cells just before/after the word are empty; and any newly-written
    /// cell has no occupied neighbor in the perpendicular axis (so parallel
    /// words don't fuse).
    private func isValid(_ p: Placement, given occupied: [GridCoord: Character]) -> Bool {
        let chars = Array(p.answer)
        var crossings = 0
        // Before/after must be clear.
        let before = p.direction == .across
            ? GridCoord(row: p.origin.row, col: p.origin.col - 1)
            : GridCoord(row: p.origin.row - 1, col: p.origin.col)
        let lastCell = p.cells.last!
        let after = p.direction == .across
            ? GridCoord(row: lastCell.row, col: lastCell.col + 1)
            : GridCoord(row: lastCell.row + 1, col: lastCell.col)
        if occupied[before] != nil || occupied[after] != nil { return false }

        for (i, cell) in p.cells.enumerated() {
            if let existing = occupied[cell] {
                if existing != chars[i] { return false }
                crossings += 1
            } else {
                // Newly written cell: perpendicular neighbors must be empty.
                let perp: [GridCoord] = p.direction == .across
                    ? [GridCoord(row: cell.row - 1, col: cell.col), GridCoord(row: cell.row + 1, col: cell.col)]
                    : [GridCoord(row: cell.row, col: cell.col - 1), GridCoord(row: cell.row, col: cell.col + 1)]
                if perp.contains(where: { occupied[$0] != nil }) { return false }
            }
        }
        return crossings >= 1
    }

    private func normalize(_ placed: [Placement]) -> [GridSlot] {
        let allCells = placed.flatMap(\.cells)
        let minRow = allCells.map(\.row).min() ?? 0
        let minCol = allCells.map(\.col).min() ?? 0
        return placed.enumerated().map { idx, p in
            GridSlot(
                id: idx,
                answer: p.answer,
                origin: GridCoord(row: p.origin.row - minRow, col: p.origin.col - minCol),
                direction: p.direction
            )
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter CrosswordLayoutEngineTests`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add Sources/LevelGen/CrosswordLayoutEngine.swift Tests/LevelGenTests/CrosswordLayoutEngineTests.swift
git commit -m "feat(levelgen): greedy seeded crossword layout engine"
```

---

### Task 7: SceneCreaturePicker — seeded scene/creature per theme

**Files:**
- Create: `Sources/LevelGen/SceneCreaturePicker.swift`
- Test: `Tests/LevelGenTests/SceneCreaturePickerTests.swift`

Pools are passed in (the app wires real asset ids in the migration plan); the package stays asset-agnostic and testable.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import LevelGen

final class SceneCreaturePickerTests: XCTestCase {
    let pools = ThemePools(
        scenes: [.zen: ["garden", "pond"], .doom: ["crypt", "abyss"]],
        creatures: [.zen: ["koi"], .doom: ["shoggoth", "vampire"]]
    )

    func test_picksFromTheCorrectThemePool() {
        let pick = SceneCreaturePicker(pools: pools).pick(theme: .doom, index: 0)
        XCTAssertTrue(pools.scenes[.doom]!.contains(pick.sceneID))
        XCTAssertTrue(pools.creatures[.doom]!.contains(pick.creatureID))
    }

    func test_isDeterministic() {
        let p = SceneCreaturePicker(pools: pools)
        XCTAssertEqual(p.pick(theme: .zen, index: 4).sceneID, p.pick(theme: .zen, index: 4).sceneID)
        XCTAssertEqual(p.pick(theme: .zen, index: 4).creatureID, p.pick(theme: .zen, index: 4).creatureID)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SceneCreaturePickerTests`
Expected: FAIL — types not found.

- [ ] **Step 3: Write the implementation**

```swift
import Foundation
import GameCore

public struct ThemePools: Sendable {
    public let scenes: [Theme: [String]]
    public let creatures: [Theme: [String]]
    public init(scenes: [Theme: [String]], creatures: [Theme: [String]]) {
        self.scenes = scenes
        self.creatures = creatures
    }
}

public struct SceneCreaturePicker: Sendable {
    private let pools: ThemePools
    public init(pools: ThemePools) { self.pools = pools }

    public func pick(theme: Theme, index: Int) -> (sceneID: String, creatureID: String) {
        let scenes = (pools.scenes[theme] ?? []).sorted()
        let creatures = (pools.creatures[theme] ?? []).sorted()
        precondition(!scenes.isEmpty && !creatures.isEmpty, "empty pool for \(theme)")
        var rng = SeededRandom(seed: WheelPicker.seed(theme: theme, band: .easy, index: index) ^ 0xC0FFEE)
        let scene = scenes[Int(rng.next() % UInt64(scenes.count))]
        let creature = creatures[Int(rng.next() % UInt64(creatures.count))]
        return (scene, creature)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SceneCreaturePickerTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/LevelGen/SceneCreaturePicker.swift Tests/LevelGenTests/SceneCreaturePickerTests.swift
git commit -m "feat(levelgen): seeded scene/creature picker"
```

---

### Task 8: LevelSeed + ProceduralGenerator

**Files:**
- Create: `Sources/LevelGen/LevelSeed.swift`
- Create: `Sources/LevelGen/ProceduralGenerator.swift`
- Test: `Tests/LevelGenTests/ProceduralGeneratorTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import GameCore
@testable import LevelGen

final class ProceduralGeneratorTests: XCTestCase {
    let pools = ThemePools(
        scenes: [.zen: ["garden"], .doom: ["crypt"]],
        creatures: [.zen: ["koi"], .doom: ["shoggoth"]]
    )

    func makeGen() -> ProceduralGenerator {
        ProceduralGenerator(wordProvider: SeedListWordProvider(), pools: pools)
    }

    func test_levelIsDeterministicForSameSeed() {
        let seed = LevelSeed(theme: .zen, band: .medium, index: 2)
        let a = makeGen().level(for: seed)
        let b = makeGen().level(for: seed)
        XCTAssertEqual(a.id, b.id)
        XCTAssertEqual(a.wheel.tiles.map(\.letter), b.wheel.tiles.map(\.letter))
        XCTAssertEqual(a.slots.map(\.answer), b.slots.map(\.answer))
    }

    func test_everySlotWordIsBuildableFromWheel() {
        let level = makeGen().level(for: LevelSeed(theme: .doom, band: .hard, index: 0))
        let multiset = level.wheel.multiset
        XCTAssertFalse(level.slots.isEmpty)
        for slot in level.slots {
            XCTAssertTrue(multiset.canBuild(slot.answer), "\(slot.answer) not buildable")
        }
    }

    func test_idEncodesSeed() {
        let level = makeGen().level(for: LevelSeed(theme: .doom, band: .hard, index: 5))
        XCTAssertEqual(level.id, "doom-hard-5")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ProceduralGeneratorTests`
Expected: FAIL — types not found.

- [ ] **Step 3: Write LevelSeed**

`Sources/LevelGen/LevelSeed.swift`:
```swift
import GameCore

public struct LevelSeed: Equatable, Sendable {
    public let theme: Theme
    public let band: DifficultyBand
    public let index: Int
    public init(theme: Theme, band: DifficultyBand, index: Int) {
        self.theme = theme
        self.band = band
        self.index = index
    }
    /// Stable, human-readable level id.
    public var id: String { "\(theme.rawValue)-\(band.rawValue)-\(index)" }
}
```

- [ ] **Step 4: Write ProceduralGenerator**

`Sources/LevelGen/ProceduralGenerator.swift`:
```swift
import Foundation
import GameCore

/// Assembles a deterministic `Level` from a seed using a word provider and the
/// layout engine. The provider supplies validated, buildable themed words; the
/// generator tops up from the seed list to guarantee enough grid words.
public struct ProceduralGenerator: Sendable {
    private let wordProvider: any ThemedWordProvider
    private let fallback = SeedListWordProvider()
    private let pools: ThemePools
    private let layout = CrosswordLayoutEngine()

    /// Minimum grid words a level must contain.
    public static let minSlots = 4
    /// Maximum grid words to place.
    public static let maxSlots = 8

    public init(wordProvider: any ThemedWordProvider, pools: ThemePools) {
        self.wordProvider = wordProvider
        self.pools = pools
    }

    public func level(for seed: LevelSeed) -> Level {
        let wheel = WheelPicker.wheel(theme: seed.theme, band: seed.band, index: seed.index)

        // Gather candidate words; merge provider output with a deterministic
        // top-up so we always have enough to fill a grid.
        var pool = wordProvider.words(forWheel: wheel, theme: seed.theme, limit: Self.maxSlots * 3)
        if pool.count < Self.minSlots {
            let extra = fallback.words(forWheel: wheel, theme: seed.theme, limit: Self.maxSlots * 3)
            for w in extra where !pool.contains(w) { pool.append(w) }
        }

        let layoutSeed = WheelPicker.seed(theme: seed.theme, band: seed.band, index: seed.index) ^ 0x5EED
        let slots = layout.layout(words: pool, maxSlots: Self.maxSlots, seed: layoutSeed)

        let visual = SceneCreaturePicker(pools: pools).pick(theme: seed.theme, index: seed.index)
        return Level(
            id: seed.id,
            wheel: wheel,
            slots: slots,
            sceneID: visual.sceneID,
            creatureID: visual.creatureID
        )
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter ProceduralGeneratorTests`
Expected: PASS (3 tests)

- [ ] **Step 6: Commit**

```bash
git add Sources/LevelGen/LevelSeed.swift Sources/LevelGen/ProceduralGenerator.swift Tests/LevelGenTests/ProceduralGeneratorTests.swift
git commit -m "feat(levelgen): ProceduralGenerator assembles deterministic levels"
```

---

### Task 9: ProceduralLevelLibrary — ordered seeded sequence

**Files:**
- Create: `Sources/LevelGen/ProceduralLevelLibrary.swift`
- Test: `Tests/LevelGenTests/ProceduralLevelLibraryTests.swift`

Sequence default: packs of 10 levels; theme alternates per pack (zen, doom, zen, …); band escalates with depth (easy→master, then repeats at master).

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import GameCore
@testable import LevelGen

final class ProceduralLevelLibraryTests: XCTestCase {
    let lib = ProceduralLevelLibrary(packSize: 10)

    func test_orderedSeedsAreStableAndDistinct() {
        let ids = (0..<25).map { lib.seed(atOrder: $0).id }
        XCTAssertEqual(ids.count, Set(ids).count, "ids must be unique")
        XCTAssertEqual(lib.seed(atOrder: 0).id, ProceduralLevelLibrary(packSize: 10).seed(atOrder: 0).id)
    }

    func test_themeAlternatesPerPack() {
        XCTAssertEqual(lib.seed(atOrder: 0).theme, .zen)   // pack 0
        XCTAssertEqual(lib.seed(atOrder: 9).theme, .zen)
        XCTAssertEqual(lib.seed(atOrder: 10).theme, .doom) // pack 1
        XCTAssertEqual(lib.seed(atOrder: 20).theme, .zen)  // pack 2
    }

    func test_lookupByIDRoundTrips() {
        let seed = lib.seed(atOrder: 13)
        XCTAssertEqual(lib.seed(forID: seed.id)?.id, seed.id)
        XCTAssertNil(lib.seed(forID: "nonsense-id-x"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ProceduralLevelLibraryTests`
Expected: FAIL — type not found.

- [ ] **Step 3: Write the implementation**

```swift
import Foundation
import GameCore

/// Deterministic ordered sequence of level seeds. Order N maps to a stable
/// `LevelSeed`; ids are reversible so progress can be keyed by id.
public struct ProceduralLevelLibrary: Sendable {
    public let packSize: Int
    public init(packSize: Int = 10) { self.packSize = packSize }

    private static let bandOrder: [DifficultyBand] = [.easy, .medium, .hard, .expert, .master]

    public func seed(atOrder order: Int) -> LevelSeed {
        let pack = order / packSize
        let withinPack = order % packSize
        let theme: Theme = (pack % 2 == 0) ? .zen : .doom
        // Band escalates with depth, clamped at master.
        let bandIdx = min(order / packSize, Self.bandOrder.count - 1)
        let band = Self.bandOrder[bandIdx]
        // Index within the (theme, band) space is the global order, keeping ids unique.
        _ = withinPack
        return LevelSeed(theme: theme, band: band, index: order)
    }

    public func seed(forID id: String) -> LevelSeed? {
        let parts = id.split(separator: "-")
        guard parts.count == 3,
              let theme = Theme(rawValue: String(parts[0])),
              let band = DifficultyBand(rawValue: String(parts[1])),
              let index = Int(parts[2]) else { return nil }
        return LevelSeed(theme: theme, band: band, index: index)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ProceduralLevelLibraryTests`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add Sources/LevelGen/ProceduralLevelLibrary.swift Tests/LevelGenTests/ProceduralLevelLibraryTests.swift
git commit -m "feat(levelgen): ProceduralLevelLibrary ordered seeded sequence"
```

---

### Task 10: Full-suite green + solvability sweep

**Files:**
- Test: `Tests/LevelGenTests/SolvabilitySweepTests.swift`

- [ ] **Step 1: Write a sweep test asserting invariants across many seeds**

```swift
import XCTest
import GameCore
@testable import LevelGen

final class SolvabilitySweepTests: XCTestCase {
    func test_first50LevelsAreValid() {
        let pools = ThemePools(
            scenes: [.zen: ["garden", "pond"], .doom: ["crypt", "abyss"]],
            creatures: [.zen: ["koi", "crane"], .doom: ["shoggoth", "vampire"]]
        )
        let lib = ProceduralLevelLibrary(packSize: 10)
        let gen = ProceduralGenerator(wordProvider: SeedListWordProvider(), pools: pools)
        for order in 0..<50 {
            let level = gen.level(for: lib.seed(atOrder: order))
            XCTAssertGreaterThanOrEqual(level.slots.count, 1, "order \(order) empty grid")
            let multiset = level.wheel.multiset
            for slot in level.slots {
                XCTAssertTrue(multiset.canBuild(slot.answer), "order \(order): \(slot.answer) unbuildable")
            }
            // No two slots conflict on a shared cell.
            var m: [GridCoord: Character] = [:]
            for slot in level.slots {
                let chars = Array(slot.answer)
                for (i, cell) in slot.cells.enumerated() {
                    if let e = m[cell] { XCTAssertEqual(e, chars[i], "order \(order) conflict") }
                    else { m[cell] = chars[i] }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Run the whole suite**

Run: `swift test`
Expected: PASS — all `LevelGenTests` plus existing package tests green.

> If the sweep reveals levels with too few slots for some small wheels, expand the seed lists (Task 3) with more short sub-words for those base words, then re-run. This is curation, not code change.

- [ ] **Step 3: Commit**

```bash
git add Tests/LevelGenTests/SolvabilitySweepTests.swift
git commit -m "test(levelgen): solvability sweep across first 50 levels"
```

---

## Self-Review

- **Spec coverage:** §4 module boundary (pure `LevelGen`) ✓ Tasks 1–9; §5 pipeline (wheel→pool→grid→scene/creature) ✓ Tasks 4,5,6,7,8; §5 top-up ✓ Task 8; §6 theme model (seed lists + theme) ✓ Tasks 2,3,9; §7 stable seeded ids ✓ Tasks 8,9; §9 solvability invariants ✓ Tasks 6,8,10; §10 testing (determinism, buildability, seed-list format) ✓ throughout. **Deferred to later plans (by design):** FM provider (§5 primary, §8) → Plan 2; app wiring/migration of `LevelLibrary`/`GameStore`/`GameContainerView`, real scene/creature pools, retiring `levels.json` (§7) → Plan 1b; `SystemDictionary` filtering of FM output (§5) → Plan 2; image seam (§11) → Plan 3.
- **Placeholder scan:** none — every step has concrete code/commands. Seed lists contain real words.
- **Type consistency:** `ThemedWordProvider.words(forWheel:theme:limit:)` used identically in Tasks 5 & 8; `WheelPicker.seed(theme:band:index:)` reused in Tasks 7 & 8; `LevelSeed.id` format `"theme-band-index"` consistent in Tasks 8 & 9; `GridSlot`/`Wheel`/`Level` initializers match GameCore (verified).

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-30-procedural-levels-1-levelgen.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
