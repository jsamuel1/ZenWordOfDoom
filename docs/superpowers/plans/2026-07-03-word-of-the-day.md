# Word of the Day Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A curated Zen/Doom "Word of the Day" (8-10 letters, same word for every player each calendar day) plays as a bonus Pangram-Hunt puzzle in the existing Daily slot, with its own shared reveal art and a new two-row wheel shape for 8+ letter wheels.

**Architecture:** Two new pure `LevelGen` types (`WordOfTheDay` for deterministic per-day word selection, `WordOfTheDayImages` for the word→illustration-slug mapping) plug into the existing `DailyPuzzle`/`ProceduralGenerator`/`LevelService` pipeline via one new method each (`DailyPuzzle.wordOfTheDay(forID:)`, `ProceduralGenerator.dailyLevel(for:word:)`). The wheel UI gains a two-row "stadium" layout for 8+ tile wheels (extracted into a new pure `WheelLayout` type). Reveal art reuses the existing `.scene` visual kind — the word's slug simply becomes that day's `sceneID` — so `BundledVisuals`/`VisualPrompts`/`GeneratedImageView` need no new abstractions, just new entries. Images are generated offline via the `agy` CLI into the existing bundled-asset pipeline.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest, Swift Package Manager (`LevelGen`/`GameCore` targets), XcodeGen, `agy` (Google Antigravity CLI, local, image-capable).

## Global Constraints

- Curated words are 8-10 letters only (spec §3.4); every word must be a genuine English dictionary word.
- Same word for every player on the same calendar UTC day — determinism must not depend on device, locale, or wall-clock time zone.
- A theme's word list must not repeat a word until the entire list has cycled once (spec §3.4).
- The Word of the Day is a bonus — it must never gate or block level-select's normal progression (spec §2, §5.7).
- Reveal art is offline-generated (via `agy`) and bundled — no per-device runtime generation for word images (spec §2).
- Wheels of 8+ tiles use the two-row stadium shape with same-row drag trails curving inward toward the gap between rows (spec §4.3, confirmed via mockup review); wheels under 8 tiles keep the existing circle layout unchanged.
- `agy` has usage limits/throttling — the image-authoring script must pace requests and be resumable (spec §4.5, §6).

---

### Task 1: Curated word lists + `WordOfTheDay` list loader

**Files:**
- Create: `Sources/LevelGen/Resources/daily-zen.txt`
- Create: `Sources/LevelGen/Resources/daily-doom.txt`
- Create: `Sources/LevelGen/WordOfTheDay.swift`
- Test: `Tests/LevelGenTests/WordOfTheDayTests.swift`

**Interfaces:**
- Produces: `public enum WordOfTheDay { public static func words(for theme: Theme) -> [String] }` — later tasks (2, 4, 9, 10) read the curated list through this, never by reaching into the resource files directly.

- [ ] **Step 1: Create the curated Zen word list**

Create `Sources/LevelGen/Resources/daily-zen.txt` with exactly this content (77 words, one per line, alphabetically sorted, all verified 8-9 letter entries present in the bundled `words.txt` corpus, plus 10 hand-verified real 10-letter words the corpus itself is too short to contain — see Global Constraints):

```
BALANCED
BEAUTIFUL
BLESSEDLY
BLISSFULLY
BLOOMING
BLOSSOMED
BLOSSOMS
BOUNDLESS
BREATHING
CALMNESS
CENTERED
CHERISHED
COMPASSION
COMPOSED
CONTENTED
DAYBREAK
DREAMLAND
DRIFTING
DRIFTWOOD
EMBRACING
EVENSONG
FLOATING
FLOURISH
FRAGRANCE
GARDENIA
GRACEFUL
GRACEFULLY
GRATEFUL
GROUNDED
HARMONIOUS
HARMONIZE
HEAVENLY
HORIZONS
LANTERNS
MEDITATE
MEDITATION
MINDFULLY
MOONBEAMS
MOONLIGHT
MOUNTAIN
NIGHTFALL
NURTURING
ORCHARDS
PEACEABLE
PEACEFUL
PEACEFULLY
QUIETUDE
RADIANCE
RAINDROPS
RELAXING
RESTFULLY
SANCTUARY
SANDALWOOD
SEASHELL
SERENITY
SLUMBERED
SNOWFALL
SOLITUDE
SOOTHING
STARDUST
STARLIGHT
STILLNESS
SUNBEAMS
SUNLIGHT
THANKFUL
TRANQUILLY
TREASURED
TWILIGHT
UNRUFFLED
UNWINDING
WATERFALL
WEIGHTLESS
WELLSPRING
WHISPERED
WHISPERS
WHOLENESS
WONDROUS
```

- [ ] **Step 2: Create the curated Doom word list**

Create `Sources/LevelGen/Resources/daily-doom.txt` with exactly this content (61 words, same construction as Step 1):

```
ABANDONED
APOCALYPSE
BLOODIED
CATACOMBS
CREATURE
CREEPING
CRUMBLING
DAMNATION
DECREPIT
DESECRATED
DESOLATE
DEVILISH
DREADFUL
ENTOMBED
FEROCIOUS
FESTERING
FIENDISH
FORBIDDEN
FORGOTTEN
FORSAKEN
GARGOYLES
GHOULISH
GRAVESTONE
GRAVEYARD
GRUESOMELY
HAUNTING
HOLLOWED
INFERNAL
MAELSTROM
MALEVOLENT
MALICIOUS
MERCILESS
MIDNIGHT
MOLDERING
MONSTROUS
MOURNFUL
NECROMANCY
NIGHTMARE
NIGHTSHADE
POISONOUS
PUTREFYING
REVENANT
RUTHLESS
SACRIFICE
SCREAMING
SEPULCHRE
SHADOWED
SHATTERED
SHRIEKING
SINISTER
SKELETONS
SORROWFUL
SPECTRAL
TENTACLES
TERRIFYING
TOMBSTONE
VAMPIRES
VENOMOUS
WEREWOLVES
WITHERED
WRETCHED
```

- [ ] **Step 3: Write the failing test for the list loader**

Create `Tests/LevelGenTests/WordOfTheDayTests.swift`:

```swift
import XCTest
import GameCore
@testable import LevelGen

final class WordOfTheDayTests: XCTestCase {
    func testListsLoadAndAreNonEmpty() {
        XCTAssertEqual(WordOfTheDay.words(for: .zen).count, 77)
        XCTAssertEqual(WordOfTheDay.words(for: .doom).count, 61)
    }

    func testEveryWordIsEightToTenLettersUppercaseAndUnique() {
        for theme in Theme.allCases {
            let words = WordOfTheDay.words(for: theme)
            XCTAssertEqual(Set(words).count, words.count, "\(theme) list has duplicates")
            for word in words {
                XCTAssertTrue((8...10).contains(word.count), "\(word) is \(word.count) letters")
                XCTAssertEqual(word, word.uppercased(), "\(word) is not uppercase")
                XCTAssertTrue(word.allSatisfy { $0.isLetter }, "\(word) has non-letter characters")
            }
        }
    }

    func testNoWordAppearsInBothThemes() {
        let overlap = Set(WordOfTheDay.words(for: .zen)).intersection(WordOfTheDay.words(for: .doom))
        XCTAssertTrue(overlap.isEmpty, "words shared across themes: \(overlap)")
    }

    /// 8-9 letter curated words must be real dictionary entries; the bundled
    /// corpus itself is the project's existing ground truth for "real word"
    /// (it's what generation validates every other word against). 10-letter
    /// words are skipped here — the corpus is filtered to 3-9 letters, so it
    /// structurally cannot contain them; those are validated against the
    /// live system dictionary instead (see WordOfTheDayImagesTests in the
    /// app target, which has UITextChecker access).
    func testEightAndNineLetterWordsAreInGeneralCorpus() {
        for theme in Theme.allCases {
            for word in WordOfTheDay.words(for: theme) where word.count <= 9 {
                XCTAssertTrue(GeneralWordList.shared.contains(word),
                              "\(word) (\(theme)) not found in the general corpus")
            }
        }
    }
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `swift test --filter WordOfTheDayTests`
Expected: FAIL — `WordOfTheDay` doesn't exist yet (build error).

- [ ] **Step 5: Implement the list loader**

Create `Sources/LevelGen/WordOfTheDay.swift`:

```swift
import Foundation

/// The curated Word of the Day: a hand-picked list of evocative 8-10 letter
/// Zen/Doom words, bundled per theme (`Resources/daily-<theme>.txt`). This
/// file only loads and exposes the lists; day-based selection lives here too
/// (added in Task 2) so the whole "which word for which day" concern stays
/// in one small, pure, headlessly-testable type.
public enum WordOfTheDay {
    /// The curated list for a theme, in a fixed, well-defined base order
    /// (alphabetical) — the order Task 2's per-cycle shuffle starts from.
    public static func words(for theme: Theme) -> [String] {
        byTheme[theme] ?? []
    }

    private static let byTheme: [Theme: [String]] = {
        var map: [Theme: [String]] = [:]
        for theme in Theme.allCases {
            map[theme] = load(resource: "daily-\(theme.rawValue)").sorted()
        }
        return map
    }()

    private static func load(resource: String) -> [String] {
        guard let url = Bundle.module.url(forResource: resource, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `swift test --filter WordOfTheDayTests`
Expected: PASS (all 4 tests)

- [ ] **Step 7: Commit**

```bash
git add Sources/LevelGen/Resources/daily-zen.txt Sources/LevelGen/Resources/daily-doom.txt \
        Sources/LevelGen/WordOfTheDay.swift Tests/LevelGenTests/WordOfTheDayTests.swift
git commit -m "feat(levelgen): curated Word of the Day lists + loader"
```

---

### Task 2: Deterministic per-day word selection (shuffle-cycle)

**Files:**
- Modify: `Sources/LevelGen/WordOfTheDay.swift`
- Modify: `Tests/LevelGenTests/WordOfTheDayTests.swift`

**Interfaces:**
- Consumes: `WordOfTheDay.words(for: Theme) -> [String]` (Task 1); `FNV1a.hash(String) -> UInt64` and `SeededRandom(seed: UInt64)` (both existing, `Sources/LevelGen/FNV1a.swift` and `Sources/LevelGen/SeededRandom.swift`).
- Produces: `public static func word(forTheme theme: Theme, dayNumber: Int) -> String` — Task 3 calls this.

- [ ] **Step 1: Write the failing tests**

Add to `Tests/LevelGenTests/WordOfTheDayTests.swift`:

```swift
    func testWordIsDeterministicForSameThemeAndDay() {
        let a = WordOfTheDay.word(forTheme: .zen, dayNumber: 100)
        let b = WordOfTheDay.word(forTheme: .zen, dayNumber: 100)
        XCTAssertEqual(a, b)
    }

    func testWordVariesAcrossDifferentDays() {
        let a = WordOfTheDay.word(forTheme: .zen, dayNumber: 0)
        let b = WordOfTheDay.word(forTheme: .zen, dayNumber: 1)
        XCTAssertNotEqual(a, b)
    }

    func testNoRepeatWithinACycle() {
        for theme in Theme.allCases {
            let cycleLength = WordOfTheDay.words(for: theme).count
            let words = (0..<cycleLength).map { WordOfTheDay.word(forTheme: theme, dayNumber: $0) }
            XCTAssertEqual(Set(words).count, cycleLength, "\(theme) repeated a word within one cycle")
        }
    }

    func testReshufflesDifferentlyAcrossCycles() {
        let cycleLength = WordOfTheDay.words(for: .zen).count
        let firstCycle = (0..<cycleLength).map { WordOfTheDay.word(forTheme: .zen, dayNumber: $0) }
        let secondCycle = (0..<cycleLength).map { WordOfTheDay.word(forTheme: .zen, dayNumber: cycleLength + $0) }
        XCTAssertNotEqual(firstCycle, secondCycle, "second cycle used the same order as the first")
        // Still the same *set* of words, just reordered.
        XCTAssertEqual(Set(firstCycle), Set(secondCycle))
    }

    func testEveryReturnedWordIsFromTheThemesList() {
        let zenSet = Set(WordOfTheDay.words(for: .zen))
        for day in 0..<200 {
            XCTAssertTrue(zenSet.contains(WordOfTheDay.word(forTheme: .zen, dayNumber: day)))
        }
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter WordOfTheDayTests`
Expected: FAIL — `word(forTheme:dayNumber:)` doesn't exist yet (build error).

- [ ] **Step 3: Implement the shuffle-cycle selection**

Replace the body of `Sources/LevelGen/WordOfTheDay.swift` with:

```swift
import Foundation

/// The curated Word of the Day: a hand-picked list of evocative 8-10 letter
/// Zen/Doom words, bundled per theme (`Resources/daily-<theme>.txt`), plus
/// deterministic per-day selection so every player sees the same word.
///
/// Selection uses a per-cycle Fisher-Yates shuffle (our own `SeededRandom`,
/// never the standard library's `shuffled(using:)` — its algorithm isn't a
/// documented, version-stable contract, and this needs to produce the exact
/// same word on the exact same day forever, the same way `FNV1a`'s offset
/// basis is pinned rather than "corrected"). A day-number-modulo-cycle-length
/// pick guarantees a theme's list never repeats a word until every word in
/// it has been used once; the cycle number reseeds the shuffle so the next
/// pass through the list uses a different order, not the same one again.
public enum WordOfTheDay {
    public static func words(for theme: Theme) -> [String] {
        byTheme[theme] ?? []
    }

    /// The word for a given theme and day number (days since a fixed epoch —
    /// see `DailyPuzzle.daysFromCivil`, Task 3). Always the same word for the
    /// same (theme, dayNumber) pair, on every device, forever.
    public static func word(forTheme theme: Theme, dayNumber: Int) -> String {
        let list = words(for: theme)
        precondition(!list.isEmpty, "no Word-of-the-Day list for \(theme)")
        let cycleLength = list.count
        let cycleIndex = dayNumber % cycleLength
        let cycleNumber = dayNumber / cycleLength
        let seed = FNV1a.hash("wotd-\(theme.rawValue)-\(cycleNumber)")
        return fisherYatesShuffle(list, seed: seed)[cycleIndex]
    }

    private static func fisherYatesShuffle(_ items: [String], seed: UInt64) -> [String] {
        var rng = SeededRandom(seed: seed)
        var array = items
        guard array.count > 1 else { return array }
        for i in stride(from: array.count - 1, to: 0, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            array.swapAt(i, j)
        }
        return array
    }

    private static let byTheme: [Theme: [String]] = {
        var map: [Theme: [String]] = [:]
        for theme in Theme.allCases {
            map[theme] = load(resource: "daily-\(theme.rawValue)").sorted()
        }
        return map
    }()

    private static func load(resource: String) -> [String] {
        guard let url = Bundle.module.url(forResource: resource, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter WordOfTheDayTests`
Expected: PASS (all 9 tests)

- [ ] **Step 5: Commit**

```bash
git add Sources/LevelGen/WordOfTheDay.swift Tests/LevelGenTests/WordOfTheDayTests.swift
git commit -m "feat(levelgen): deterministic per-day Word of the Day selection"
```

---

### Task 3: `DailyPuzzle.wordOfTheDay(forID:)`

**Files:**
- Modify: `Sources/LevelGen/DailyPuzzle.swift`
- Modify: `Tests/LevelGenTests/DailyPuzzleTests.swift`

**Interfaces:**
- Consumes: `WordOfTheDay.word(forTheme:dayNumber:) -> String` (Task 2); existing `DailyPuzzle.seed(forID:) -> LevelSeed?`.
- Produces: `public static func wordOfTheDay(forID id: String) -> (theme: Theme, word: String)?` — Task 7 (`ProceduralGenerator`) and Task 8 (`LevelService`) call this.

- [ ] **Step 1: Write the failing tests**

Add to `Tests/LevelGenTests/DailyPuzzleTests.swift`:

```swift
    func testWordOfTheDayIsDeterministicAndDateSensitive() {
        let a = DailyPuzzle.wordOfTheDay(forID: "daily-2026-07-02")
        let b = DailyPuzzle.wordOfTheDay(forID: "daily-2026-07-02")
        let c = DailyPuzzle.wordOfTheDay(forID: "daily-2026-07-03")
        XCTAssertNotNil(a)
        XCTAssertEqual(a?.word, b?.word)
        XCTAssertEqual(a?.theme, b?.theme)
        XCTAssertNotEqual(a?.word, c?.word)
    }

    func testWordOfTheDayThemeMatchesSeedTheme() {
        for day in 1...28 {
            let id = String(format: "daily-2026-07-%02d", day)
            let seed = DailyPuzzle.seed(forID: id)!
            let wotd = DailyPuzzle.wordOfTheDay(forID: id)!
            XCTAssertEqual(seed.theme, wotd.theme)
        }
    }

    func testWordOfTheDayWordIsEightToTenLetters() {
        for day in 1...28 {
            let id = String(format: "daily-2026-07-%02d", day)
            let word = DailyPuzzle.wordOfTheDay(forID: id)!.word
            XCTAssertTrue((8...10).contains(word.count), "\(word) is \(word.count) letters")
        }
    }

    func testWordOfTheDayRejectsGarbage() {
        XCTAssertNil(DailyPuzzle.wordOfTheDay(forID: "daily-not-a-date"))
        XCTAssertNil(DailyPuzzle.wordOfTheDay(forID: "zen-easy-0"))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter DailyPuzzleTests`
Expected: FAIL — `wordOfTheDay(forID:)` doesn't exist yet (build error).

- [ ] **Step 3: Refactor date parsing into a shared helper, then add `wordOfTheDay(forID:)`**

Replace the full contents of `Sources/LevelGen/DailyPuzzle.swift`:

```swift
import Foundation
import GameCore

/// The daily puzzle: one fixed-seed level per calendar day (SPEC §8), the same
/// for every player. Ids are `daily-yyyy-MM-dd`; the seed is FNV-1a over the id,
/// so it is stable across devices and app versions.
public enum DailyPuzzle {
    public static func isDailyID(_ id: String) -> Bool { id.hasPrefix("daily-") }

    public static func id(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "daily-%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    /// Seed for a daily id, or nil if the id isn't a well-formed daily date.
    /// Band rotates through the mid-game (never a 5-letter warm-up, never the
    /// 9-letter deep end); theme flips on the hash.
    public static func seed(forID id: String) -> LevelSeed? {
        guard dateComponents(forID: id) != nil else { return nil }
        let h = FNV1a.hash(id)
        let theme: Theme = h % 2 == 0 ? .zen : .doom
        let bands: [DifficultyBand] = [.medium, .hard, .expert]
        let band = bands[Int((h >> 8) % 3)]
        // Large offset keeps daily indices clear of the campaign's early orders
        // in generated content, without colliding ids (dailies re-key by date).
        let index = 1_000_000 + Int((h >> 16) % 1_000_000)
        return LevelSeed(theme: theme, band: band, index: index)
    }

    /// The curated Word of the Day for this daily id, and the theme it
    /// belongs to (always the same theme `seed(forID:)` picks for this id —
    /// there is only one theme decision per day, shared by both the word and
    /// the level's scene/creature pool). Nil for a malformed id.
    public static func wordOfTheDay(forID id: String) -> (theme: Theme, word: String)? {
        guard let (year, month, day) = dateComponents(forID: id),
              let seed = seed(forID: id) else { return nil }
        let dayNumber = daysFromCivil(year: year, month: month, day: day)
        return (seed.theme, WordOfTheDay.word(forTheme: seed.theme, dayNumber: dayNumber))
    }

    /// Parses and validates the `yyyy-MM-dd` suffix of a daily id. Shared by
    /// `seed(forID:)` and `wordOfTheDay(forID:)` so both agree on what counts
    /// as a valid daily id.
    private static func dateComponents(forID id: String) -> (year: Int, month: Int, day: Int)? {
        guard isDailyID(id) else { return nil }
        let day = String(id.dropFirst("daily-".count))
        let parts = day.split(separator: "-")
        guard parts.count == 3, parts[0].count == 4,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d), y >= 2026 else { return nil }
        return (y, m, d)
    }

    /// Days since 1970-01-01, pure integer arithmetic (Howard Hinnant's
    /// days-from-civil algorithm) — deliberately avoids Foundation's
    /// `Calendar`/`TimeZone` for a value that must be bit-for-bit identical
    /// on every device: the epoch and exact day count don't matter, only
    /// that it's a stable, monotonically increasing integer per calendar day.
    static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter DailyPuzzleTests`
Expected: PASS (all tests, old and new — confirms the `dateComponents` refactor didn't change `seed(forID:)` behavior)

- [ ] **Step 5: Commit**

```bash
git add Sources/LevelGen/DailyPuzzle.swift Tests/LevelGenTests/DailyPuzzleTests.swift
git commit -m "feat(levelgen): DailyPuzzle.wordOfTheDay(forID:) entry point"
```

---

### Task 4: Word → illustration-slug mapping

**Files:**
- Create: `Sources/LevelGen/WordOfTheDayImages.swift`
- Test: `Tests/LevelGenTests/WordOfTheDayImagesTests.swift`

**Interfaces:**
- Consumes: `WordOfTheDay.words(for: Theme) -> [String]` (Task 1).
- Produces: `public enum WordOfTheDayImages { public static func slug(forWord word: String, theme: Theme) -> String; public static func slugs(for theme: Theme) -> [String] }` — Task 5 (`VisualPrompts`), Task 6 (`BundledVisuals`), and Task 7 (`ProceduralGenerator.dailyLevel`) all use this.

- [ ] **Step 1: Write the failing tests**

Create `Tests/LevelGenTests/WordOfTheDayImagesTests.swift`:

```swift
import XCTest
import GameCore
@testable import LevelGen

final class WordOfTheDayImagesTests: XCTestCase {
    func testEverySlugListHasTwelveEntries() {
        XCTAssertEqual(WordOfTheDayImages.slugs(for: .zen).count, 12)
        XCTAssertEqual(WordOfTheDayImages.slugs(for: .doom).count, 12)
    }

    func testEverySlugIsUnique() {
        for theme in Theme.allCases {
            let slugs = WordOfTheDayImages.slugs(for: theme)
            XCTAssertEqual(Set(slugs).count, slugs.count, "\(theme) has duplicate slugs")
        }
    }

    /// Completeness: every curated word must map to one of its theme's own
    /// slugs. A word silently falling through to the wrong theme's slug (or
    /// no slug) would show mismatched or missing art for that day.
    func testEveryCuratedWordMapsToASlugOfItsOwnTheme() {
        for theme in Theme.allCases {
            let slugs = Set(WordOfTheDayImages.slugs(for: theme))
            for word in WordOfTheDay.words(for: theme) {
                let slug = WordOfTheDayImages.slug(forWord: word, theme: theme)
                XCTAssertTrue(slugs.contains(slug), "\(word) (\(theme)) mapped to unknown slug \(slug)")
            }
        }
    }

    /// Every slug should actually be used by at least one word — an unused
    /// slug is dead art we'd generate and ship for nothing.
    func testEverySlugIsUsedByAtLeastOneWord() {
        for theme in Theme.allCases {
            let used = Set(WordOfTheDay.words(for: theme).map { WordOfTheDayImages.slug(forWord: $0, theme: theme) })
            for slug in WordOfTheDayImages.slugs(for: theme) {
                XCTAssertTrue(used.contains(slug), "slug \(slug) (\(theme)) is never used")
            }
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter WordOfTheDayImagesTests`
Expected: FAIL — `WordOfTheDayImages` doesn't exist yet (build error).

- [ ] **Step 3: Implement the mapping**

Create `Sources/LevelGen/WordOfTheDayImages.swift`:

```swift
import Foundation

/// Maps a curated Word of the Day to one of 12-per-theme shared illustration
/// slugs (design spec §4.4 — many words per image, ~20-30 images total). A
/// slug's art is bundled/generated exactly like the existing scene art: the
/// word's slug simply becomes that day's `Level.sceneID`, reusing the
/// existing `.scene` visual kind rather than inventing a new one.
public enum WordOfTheDayImages {
    public static func slugs(for theme: Theme) -> [String] {
        slugsByTheme[theme] ?? []
    }

    /// The illustration slug for a curated word. Every word in
    /// `WordOfTheDay.words(for:)` is mapped below; the fallback (theme's
    /// first slug) only guards a future word added to the list without also
    /// being added here — it should never be hit for a shipped word (see
    /// `WordOfTheDayImagesTests.testEveryCuratedWordMapsToASlugOfItsOwnTheme`).
    public static func slug(forWord word: String, theme: Theme) -> String {
        byWord[word.uppercased()] ?? (slugsByTheme[theme]?.first ?? "")
    }

    private static let slugsByTheme: [Theme: [String]] = [
        .zen: ["dawn-glow", "moonlit-hush", "still-water", "quiet-garden",
               "lantern-calm", "gentle-breath", "drifting-ease", "warm-heart",
               "nurtured-soul", "calm-balance", "soft-whisper", "graceful-harmony"],
        .doom: ["ashen-ruin", "black-crypt", "cursed-hollow", "gravebound",
                "festering-dark", "shrieking-night", "monstrous-thing", "forsaken-tomb",
                "venomous-rite", "spectral-dread", "ravaged-earth", "malevolent-omen"],
    ]

    /// Word -> slug. Generated by chunking each theme's sorted word list
    /// evenly across its 12 slugs (see the design spec §4.4); the grouping
    /// is a practical partition; the slug names are the actual curated mood.
    private static let byWord: [String: String] = [
        "ABANDONED": "ashen-ruin",
        "APOCALYPSE": "ashen-ruin",
        "BALANCED": "dawn-glow",
        "BEAUTIFUL": "dawn-glow",
        "BLESSEDLY": "dawn-glow",
        "BLISSFULLY": "dawn-glow",
        "BLOODIED": "ashen-ruin",
        "BLOOMING": "dawn-glow",
        "BLOSSOMED": "dawn-glow",
        "BLOSSOMS": "dawn-glow",
        "BOUNDLESS": "moonlit-hush",
        "BREATHING": "moonlit-hush",
        "CALMNESS": "moonlit-hush",
        "CATACOMBS": "ashen-ruin",
        "CENTERED": "moonlit-hush",
        "CHERISHED": "moonlit-hush",
        "COMPASSION": "moonlit-hush",
        "COMPOSED": "moonlit-hush",
        "CONTENTED": "still-water",
        "CREATURE": "ashen-ruin",
        "CREEPING": "ashen-ruin",
        "CRUMBLING": "black-crypt",
        "DAMNATION": "black-crypt",
        "DAYBREAK": "still-water",
        "DECREPIT": "black-crypt",
        "DESECRATED": "black-crypt",
        "DESOLATE": "black-crypt",
        "DEVILISH": "cursed-hollow",
        "DREADFUL": "cursed-hollow",
        "DREAMLAND": "still-water",
        "DRIFTING": "still-water",
        "DRIFTWOOD": "still-water",
        "EMBRACING": "still-water",
        "ENTOMBED": "cursed-hollow",
        "EVENSONG": "still-water",
        "FEROCIOUS": "cursed-hollow",
        "FESTERING": "cursed-hollow",
        "FIENDISH": "gravebound",
        "FLOATING": "quiet-garden",
        "FLOURISH": "quiet-garden",
        "FORBIDDEN": "gravebound",
        "FORGOTTEN": "gravebound",
        "FORSAKEN": "gravebound",
        "FRAGRANCE": "quiet-garden",
        "GARDENIA": "quiet-garden",
        "GARGOYLES": "gravebound",
        "GHOULISH": "festering-dark",
        "GRACEFUL": "quiet-garden",
        "GRACEFULLY": "quiet-garden",
        "GRATEFUL": "quiet-garden",
        "GRAVESTONE": "festering-dark",
        "GRAVEYARD": "festering-dark",
        "GROUNDED": "lantern-calm",
        "GRUESOMELY": "festering-dark",
        "HARMONIOUS": "lantern-calm",
        "HARMONIZE": "lantern-calm",
        "HAUNTING": "festering-dark",
        "HEAVENLY": "lantern-calm",
        "HOLLOWED": "shrieking-night",
        "HORIZONS": "lantern-calm",
        "INFERNAL": "shrieking-night",
        "LANTERNS": "lantern-calm",
        "MAELSTROM": "shrieking-night",
        "MALEVOLENT": "shrieking-night",
        "MALICIOUS": "shrieking-night",
        "MEDITATE": "lantern-calm",
        "MEDITATION": "gentle-breath",
        "MERCILESS": "monstrous-thing",
        "MIDNIGHT": "monstrous-thing",
        "MINDFULLY": "gentle-breath",
        "MOLDERING": "monstrous-thing",
        "MONSTROUS": "monstrous-thing",
        "MOONBEAMS": "gentle-breath",
        "MOONLIGHT": "gentle-breath",
        "MOUNTAIN": "gentle-breath",
        "MOURNFUL": "monstrous-thing",
        "NECROMANCY": "forsaken-tomb",
        "NIGHTFALL": "gentle-breath",
        "NIGHTMARE": "forsaken-tomb",
        "NIGHTSHADE": "forsaken-tomb",
        "NURTURING": "drifting-ease",
        "ORCHARDS": "drifting-ease",
        "PEACEABLE": "drifting-ease",
        "PEACEFUL": "drifting-ease",
        "PEACEFULLY": "drifting-ease",
        "POISONOUS": "forsaken-tomb",
        "PUTREFYING": "forsaken-tomb",
        "QUIETUDE": "drifting-ease",
        "RADIANCE": "warm-heart",
        "RAINDROPS": "warm-heart",
        "RELAXING": "warm-heart",
        "RESTFULLY": "warm-heart",
        "REVENANT": "venomous-rite",
        "RUTHLESS": "venomous-rite",
        "SACRIFICE": "venomous-rite",
        "SANCTUARY": "warm-heart",
        "SANDALWOOD": "warm-heart",
        "SCREAMING": "venomous-rite",
        "SEASHELL": "nurtured-soul",
        "SEPULCHRE": "venomous-rite",
        "SERENITY": "nurtured-soul",
        "SHADOWED": "spectral-dread",
        "SHATTERED": "spectral-dread",
        "SHRIEKING": "spectral-dread",
        "SINISTER": "spectral-dread",
        "SKELETONS": "spectral-dread",
        "SLUMBERED": "nurtured-soul",
        "SNOWFALL": "nurtured-soul",
        "SOLITUDE": "nurtured-soul",
        "SOOTHING": "nurtured-soul",
        "SORROWFUL": "ravaged-earth",
        "SPECTRAL": "ravaged-earth",
        "STARDUST": "calm-balance",
        "STARLIGHT": "calm-balance",
        "STILLNESS": "calm-balance",
        "SUNBEAMS": "calm-balance",
        "SUNLIGHT": "calm-balance",
        "TENTACLES": "ravaged-earth",
        "TERRIFYING": "ravaged-earth",
        "THANKFUL": "calm-balance",
        "TOMBSTONE": "ravaged-earth",
        "TRANQUILLY": "soft-whisper",
        "TREASURED": "soft-whisper",
        "TWILIGHT": "soft-whisper",
        "UNRUFFLED": "soft-whisper",
        "UNWINDING": "soft-whisper",
        "VAMPIRES": "malevolent-omen",
        "VENOMOUS": "malevolent-omen",
        "WATERFALL": "soft-whisper",
        "WEIGHTLESS": "graceful-harmony",
        "WELLSPRING": "graceful-harmony",
        "WEREWOLVES": "malevolent-omen",
        "WHISPERED": "graceful-harmony",
        "WHISPERS": "graceful-harmony",
        "WHOLENESS": "graceful-harmony",
        "WITHERED": "malevolent-omen",
        "WONDROUS": "graceful-harmony",
        "WRETCHED": "malevolent-omen",
    ]
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter WordOfTheDayImagesTests`
Expected: PASS (all 4 tests)

- [ ] **Step 5: Commit**

```bash
git add Sources/LevelGen/WordOfTheDayImages.swift Tests/LevelGenTests/WordOfTheDayImagesTests.swift
git commit -m "feat(levelgen): word-of-the-day word to illustration-slug mapping"
```

---

### Task 5: Illustration prompts for the 24 new slugs

**Files:**
- Modify: `Sources/LevelGen/VisualPrompts.swift`
- Modify: `Tests/LevelGenTests/VisualPromptsTests.swift`

**Interfaces:**
- Consumes: `WordOfTheDayImages.slugs(for: Theme) -> [String]` (Task 4).
- Produces: `VisualPrompts.prompt(forSceneID:theme:)` now resolves all 24 new slugs (existing signature, no change) — Task 13's image-authoring script reads these prompts.

- [ ] **Step 1: Write the failing test**

Add to `Tests/LevelGenTests/VisualPromptsTests.swift`:

```swift
    /// Every Word-of-the-Day slug must have its *own* prompt, not silently
    /// fall through to the generic per-theme placeholder (the two exact
    /// strings `VisualPrompts` falls back to for an unrecognized slug) —
    /// that fallback is what every one of these 24 slugs gets *before* this
    /// task adds real entries, so this genuinely fails first.
    func testEveryWordOfTheDaySlugHasItsOwnPromptNotTheGenericFallback() {
        let genericZen = "a serene minimalist nature scene, soft pastel light, calm illustration"
        let genericDoom = "an ancient ruined place at night, faint eerie glow, ominous stylized illustration"
        for theme in Theme.allCases {
            for slug in WordOfTheDayImages.slugs(for: theme) {
                let prompt = VisualPrompts.prompt(forSceneID: slug, theme: theme)
                XCTAssertFalse(prompt.isEmpty, "slug \(slug)")
                XCTAssertNotEqual(prompt, genericZen, "slug \(slug) fell through to the generic zen prompt")
                XCTAssertNotEqual(prompt, genericDoom, "slug \(slug) fell through to the generic doom prompt")
            }
        }
    }

    func testWordOfTheDaySlugPromptsAvoidNamedIP() {
        let banned = ["cthulhu", "doomguy", "buffy", "doom guy"]
        for theme in Theme.allCases {
            for slug in WordOfTheDayImages.slugs(for: theme) {
                let p = VisualPrompts.prompt(forSceneID: slug, theme: theme).lowercased()
                for token in banned { XCTAssertFalse(p.contains(token), "\(slug) leaks \(token)") }
            }
        }
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter VisualPromptsTests`
Expected: FAIL on `testEveryWordOfTheDaySlugHasItsOwnPromptNotTheGenericFallback` — all 24 slugs currently fall through to one of the two generic strings, since none of them are in `scenePrompts` yet. `testWordOfTheDaySlugPromptsAvoidNamedIP` passes trivially either way (the generic fallback also contains no banned IP) — that's expected and fine, it's a permanent regression guard, not something meant to start red.

- [ ] **Step 3: Add the 24 new prompt entries**

In `Sources/LevelGen/VisualPrompts.swift`, add these entries to the existing `scenePrompts` dictionary (do not remove any existing entries):

```swift
        // Word-of-the-Day slugs (Zen)
        "dawn-glow": "a warm golden sunrise breaking over still hills, soft light, calm illustration",
        "moonlit-hush": "a pale full moon over quiet rooftops, soft blue light, calm illustration",
        "still-water": "a calm mountain lake at dawn reflecting distant peaks, soft mist, serene illustration",
        "quiet-garden": "a blooming garden of pale flowers in gentle morning light, calm illustration",
        "lantern-calm": "a quiet mountain path lit by paper lanterns at dusk, peaceful illustration",
        "gentle-breath": "a figure meditating cross-legged under a soft glowing sky, calm watercolor illustration",
        "drifting-ease": "a single leaf drifting slowly down a gentle stream, soft pastel illustration",
        "warm-heart": "sunlight filtering through orchard branches onto a quiet path, warm calm illustration",
        "nurtured-soul": "a quiet tide pool with a single seashell at dawn, soft pastel illustration",
        "calm-balance": "a smooth stack of balanced stones on a still shoreline, soft light, calm illustration",
        "soft-whisper": "wind gently stirring tall grass under a twilight sky, soft illustration",
        "graceful-harmony": "a slow waterfall over mossy stones in soft dappled light, serene illustration",
        // Word-of-the-Day slugs (Doom)
        "ashen-ruin": "crumbling stone ruins under an ash-grey sky, faint eerie glow, ominous stylized illustration",
        "black-crypt": "a collapsing underground crypt lit by a single dim torch, ominous stylized illustration",
        "cursed-hollow": "a twisted dead forest hollow under a bruised sky, eerie stylized illustration",
        "gravebound": "an overgrown forgotten graveyard gate at dusk, cold light, ominous stylized illustration",
        "festering-dark": "a decaying stone archway dripping with moss, sickly green glow, stylized illustration",
        "shrieking-night": "a jagged mountain pass under a blood-red moon, ominous stylized illustration",
        "monstrous-thing": "a hulking shadowed silhouette looming behind fog, deep violet glow, stylized illustration",
        "forsaken-tomb": "an abandoned stone tomb sealed shut with old chains, cold blue glow, stylized illustration",
        "venomous-rite": "a ring of dark candles around a cracked stone altar, eerie glow, stylized illustration",
        "spectral-dread": "a pale spectral shape drifting through a ruined hall, cold light, stylized illustration",
        "ravaged-earth": "a cracked and scorched battlefield under a smoky sky, ominous stylized illustration",
        "malevolent-omen": "a single glowing red eye watching from deep shadow, stylized, ominous illustration",
```

Insert these entries inside the existing `private static let scenePrompts: [String: String] = [ ... ]` dictionary literal (append before the closing `]`).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter VisualPromptsTests`
Expected: PASS (all tests, including the two new ones and the existing `testPromptsAvoidNamedIP`/`testEverySlugHasNonEmptyPrompt` which only cover `ThemePools.zenDoom`'s slugs and are unaffected)

- [ ] **Step 5: Commit**

```bash
git add Sources/LevelGen/VisualPrompts.swift Tests/LevelGenTests/VisualPromptsTests.swift
git commit -m "feat(levelgen): illustration prompts for Word of the Day slugs"
```

---

### Task 6: Bundle the 24 new slugs as known assets

**Files:**
- Modify: `App/ZenWordOfDoom/BundledVisuals.swift`
- Modify: `App/ZenWordOfDoomTests/BundledVisualsTests.swift`

**Interfaces:**
- Consumes: `WordOfTheDayImages.slugs(for: Theme) -> [String]` (Task 4, `LevelGen`).
- Produces: `BundledVisuals.knownAssets` now includes `"scene-<slug>"` for all 24 slugs — Task 13's authoring script writes actual imagesets for these names; Task 7's `dailyLevel` sets `sceneID` to a slug that this makes resolvable.

- [ ] **Step 1: Write the failing test**

Add to `App/ZenWordOfDoomTests/BundledVisualsTests.swift`:

```swift
    /// Same invariant as `testEveryZenDoomSlugHasBundledAsset`, but for the
    /// Word-of-the-Day illustration slugs (a separate pool from the regular
    /// scene/creature pools, but the same `.scene` kind and naming scheme).
    func testEveryWordOfTheDaySlugHasBundledAsset() {
        for theme in Theme.allCases {
            for slug in WordOfTheDayImages.slugs(for: theme) {
                XCTAssertTrue(BundledVisuals.knownAssets.contains("scene-\(slug)"),
                              "word-of-the-day slug '\(slug)' (\(theme)) has no bundled asset")
                XCTAssertEqual(BundledVisuals.assetName(kind: .scene, id: slug), "scene-\(slug)")
            }
        }
    }
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodegen generate && swift build` then run the app-target test suite (see project CI: `xcodebuild -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ZenWordOfDoomTests/BundledVisualsTests | xcbeautify`)
Expected: FAIL — the 24 slugs aren't in `knownAssets` yet.

- [ ] **Step 3: Add the 24 new entries to `knownAssets`**

In `App/ZenWordOfDoom/BundledVisuals.swift`, add these lines inside the existing `knownAssets: Set<String>` literal (after the existing entries, before the closing `]`):

```swift
        // Word-of-the-Day slugs (Zen)
        "scene-dawn-glow", "scene-moonlit-hush", "scene-still-water", "scene-quiet-garden",
        "scene-lantern-calm", "scene-gentle-breath", "scene-drifting-ease", "scene-warm-heart",
        "scene-nurtured-soul", "scene-calm-balance", "scene-soft-whisper", "scene-graceful-harmony",
        // Word-of-the-Day slugs (Doom)
        "scene-ashen-ruin", "scene-black-crypt", "scene-cursed-hollow", "scene-gravebound",
        "scene-festering-dark", "scene-shrieking-night", "scene-monstrous-thing", "scene-forsaken-tomb",
        "scene-venomous-rite", "scene-spectral-dread", "scene-ravaged-earth", "scene-malevolent-omen",
```

Add `import LevelGen` is already present in this file — no new import needed since `WordOfTheDayImages` lives in `LevelGen`, already imported.

- [ ] **Step 4: Run the test to verify it passes**

Run the same `xcodebuild ... -only-testing:ZenWordOfDoomTests/BundledVisualsTests` command as Step 2.
Expected: PASS. Note: this test asserts the **name mapping** is correct; the actual PNG files don't exist yet (Task 13 generates them) — until then, `GeneratedImageView` silently falls through to its procedural fallback for these slugs, exactly as documented in `BundledVisuals`'s own header comment ("an unknown/future slug cleanly falls through").

- [ ] **Step 5: Commit**

```bash
git add App/ZenWordOfDoom/BundledVisuals.swift App/ZenWordOfDoomTests/BundledVisualsTests.swift
git commit -m "feat(app): register Word of the Day illustration slugs as bundled assets"
```

---

### Task 7: `ProceduralGenerator.dailyLevel(for:word:)`

**Files:**
- Modify: `Sources/LevelGen/ProceduralGenerator.swift`
- Modify: `Tests/LevelGenTests/ProceduralGeneratorCapstoneTests.swift`

**Interfaces:**
- Consumes: `WordOfTheDayImages.slug(forWord:theme:) -> String` (Task 4); existing `SceneCreaturePicker`, `PackCatalog.pangramTarget(for:)`, `DifficultyBand(wheelSize:)` (`Sources/GameCore/Models.swift`).
- Produces: `public func dailyLevel(for seed: LevelSeed, word: String) -> Level` (synchronous, no `async`/`throws` — mirrors that Pangram-Hunt never touches the async `wordProvider`) — Task 8 (`LevelService`) calls this.

- [ ] **Step 1: Write the failing tests**

Add to `Tests/LevelGenTests/ProceduralGeneratorCapstoneTests.swift`:

```swift
    func testDailyLevelIsPangramHuntBuiltFromTheWord() {
        let seed = LevelSeed(theme: .zen, band: .medium, index: 1_234_567)
        let level = gen().dailyLevel(for: seed, word: "SERENITY")

        XCTAssertEqual(level.wheel.tiles.map(\.letter).map(String.init).joined(), "SERENITY")
        XCTAssertTrue(level.slots.isEmpty, "daily bonus level has no grid")
        guard case .pangramHunt(let target) = level.format else {
            return XCTFail("expected pangramHunt, got \(level.format)")
        }
        // SERENITY is 8 letters -> DifficultyBand.expert -> target 7.
        XCTAssertEqual(target, 7)
    }

    func testDailyLevelSceneIsTheWordsSlugAndCreatureIsFromThemePool() {
        let seed = LevelSeed(theme: .doom, band: .medium, index: 42)
        let level = gen().dailyLevel(for: seed, word: "NIGHTMARE")

        XCTAssertEqual(level.sceneID, WordOfTheDayImages.slug(forWord: "NIGHTMARE", theme: .doom))
        XCTAssertTrue((ThemePools.zenDoom.creatures[.doom] ?? []).contains(level.creatureID))
    }

    func testDailyLevelBandComesFromWordLengthNotSeedBand() {
        // Seed says .medium (implying a 6-letter wheel), but the actual word
        // is 10 letters -> the daily level's target must reflect the word's
        // real length, not the seed's nominal band.
        let seed = LevelSeed(theme: .zen, band: .medium, index: 7)
        let level = gen().dailyLevel(for: seed, word: "WELLSPRING")
        guard case .pangramHunt(let target) = level.format else {
            return XCTFail("expected pangramHunt")
        }
        XCTAssertEqual(target, PackCatalog.pangramTarget(for: .master))
    }

    func testDailyLevelIsDeterministic() {
        let seed = LevelSeed(theme: .zen, band: .hard, index: 99)
        let a = gen().dailyLevel(for: seed, word: "SANCTUARY")
        let b = gen().dailyLevel(for: seed, word: "SANCTUARY")
        XCTAssertEqual(a.creatureID, b.creatureID)
        XCTAssertEqual(a.sceneID, b.sceneID)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter ProceduralGeneratorCapstoneTests`
Expected: FAIL — `dailyLevel(for:word:)` doesn't exist yet (build error).

- [ ] **Step 3: Implement `dailyLevel`**

In `Sources/LevelGen/ProceduralGenerator.swift`, add this method inside the `ProceduralGenerator` struct (after the existing `level(for:)` method):

```swift
    /// The Word-of-the-Day bonus level: always a grid-less Pangram-Hunt whose
    /// wheel is the curated word's own letters (so it's always a completable
    /// pangram), with the word's own illustration slug as the scene (see
    /// `WordOfTheDayImages`) and a creature still drawn from the theme's
    /// normal pool. Synchronous — like pack-capstone Pangram-Hunt levels,
    /// this never touches the async `wordProvider`.
    ///
    /// The target word-count is derived from the word's *actual* length
    /// (`DifficultyBand(wheelSize:)`), not `seed.band` — `DailyPuzzle` picks
    /// `seed.band` assuming the old theme-lexicon wheel-length flow, which
    /// this bypasses; using the real wheel size keeps the word-count target
    /// scaled to what's actually achievable.
    public func dailyLevel(for seed: LevelSeed, word: String) -> Level {
        let creatureID = SceneCreaturePicker(pools: pools).pick(theme: seed.theme, index: seed.index).creatureID
        let band = DifficultyBand(wheelSize: word.count)
        return Level(
            id: seed.id,
            wheel: Wheel(letters: word),
            slots: [],
            sceneID: WordOfTheDayImages.slug(forWord: word, theme: seed.theme),
            creatureID: creatureID,
            format: .pangramHunt(target: PackCatalog.pangramTarget(for: band))
        )
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter ProceduralGeneratorCapstoneTests`
Expected: PASS (all tests, old and new)

- [ ] **Step 5: Commit**

```bash
git add Sources/LevelGen/ProceduralGenerator.swift Tests/LevelGenTests/ProceduralGeneratorCapstoneTests.swift
git commit -m "feat(levelgen): ProceduralGenerator.dailyLevel builds the Word of the Day puzzle"
```

---

### Task 8: Wire `LevelService` to the new daily path

**Files:**
- Modify: `App/ZenWordOfDoom/LevelService.swift`
- Test: `App/ZenWordOfDoomTests/LevelServiceTests.swift` (new)

**Interfaces:**
- Consumes: `DailyPuzzle.wordOfTheDay(forID:) -> (theme: Theme, word: String)?` (Task 3); `ProceduralGenerator.dailyLevel(for:word:) -> Level` (Task 7).
- Produces: `LevelService.level(id:)` now returns a Word-of-the-Day `Level` for every `daily-*` id — no interface change for callers (same method signature).

- [ ] **Step 1: Write the failing test**

Create `App/ZenWordOfDoomTests/LevelServiceTests.swift`:

```swift
import XCTest
import GameCore
import LevelGen
@testable import ZenWordOfDoom

@MainActor
final class LevelServiceTests: XCTestCase {
    func testDailyLevelIsWordOfTheDayPangramHunt() async throws {
        let service = LevelService()
        let id = "daily-2026-08-15"
        let expected = DailyPuzzle.wordOfTheDay(forID: id)!

        let level = try await XCTUnwrap(service.level(id: id))

        XCTAssertEqual(level.id, id)
        XCTAssertEqual(level.wheel.tiles.map(\.letter).map(String.init).joined(), expected.word)
        guard case .pangramHunt = level.format else {
            return XCTFail("expected pangramHunt, got \(level.format)")
        }
        XCTAssertTrue(level.slots.isEmpty)
    }

    func testDailyLevelIsMemoized() async throws {
        let service = LevelService()
        let id = "daily-2026-08-16"
        let first = try await XCTUnwrap(service.level(id: id))
        let second = try await XCTUnwrap(service.level(id: id))
        XCTAssertEqual(first.sceneID, second.sceneID)
        XCTAssertEqual(first.creatureID, second.creatureID)
    }

    /// Regression guard for the "bonus, not gating" requirement (design spec
    /// §2, §5.7): the daily slot's id space is entirely disjoint from the
    /// campaign's, so nothing about resolving/generating a daily level can
    /// ever affect `nextID(after:)`/`order(forID:)` for a campaign id.
    func testDailyIDsNeverAppearInCampaignOrdering() {
        let service = LevelService()
        let campaignIDs = service.ids(through: 30)
        XCTAssertTrue(campaignIDs.allSatisfy { !DailyPuzzle.isDailyID($0) })
        XCTAssertNil(service.order(forID: "daily-2026-08-15"))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodegen generate` then `xcodebuild -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ZenWordOfDoomTests/LevelServiceTests | xcbeautify`
Expected: FAIL — `testDailyLevelIsWordOfTheDayPangramHunt` fails because `LevelService` still routes daily ids through the generic crossword-generating `generator.level(for:)`, so `level.wheel` won't match the curated word and `level.format` likely won't be `.pangramHunt`.

- [ ] **Step 3: Wire the daily branch to `dailyLevel`**

In `App/ZenWordOfDoom/LevelService.swift`, replace the `func level(id:)` method:

```swift
    /// Resolve a level id, memoized. Returns nil when generation genuinely
    /// fails — the container shows a retry state; we no longer strand the
    /// player in a mislabeled SampleLevel.
    func level(id: String) async -> Level? {
        if let hit = cache[id] { return hit }
        if DailyPuzzle.isDailyID(id) {
            guard let seed = DailyPuzzle.seed(forID: id),
                  let wordOfTheDay = DailyPuzzle.wordOfTheDay(forID: id) else { return nil }
            let raw = generator.dailyLevel(for: seed, word: wordOfTheDay.word)
            // Re-key by date so progress/streak records land on the day.
            let level = Level(id: id, wheel: raw.wheel, slots: raw.slots,
                              sceneID: raw.sceneID, creatureID: raw.creatureID,
                              format: raw.format)
            cache[id] = level
            return level
        }
        guard let seed = library.seed(forID: id) else { return nil }
        do {
            let level = try await generator.level(for: seed)
            cache[id] = level
            return level
        } catch {
            return nil
        }
    }
```

- [ ] **Step 4: Run the test to verify it passes**

Run the same `xcodebuild ... -only-testing:ZenWordOfDoomTests/LevelServiceTests` command as Step 2.
Expected: PASS (all 3 tests)

- [ ] **Step 5: Commit**

```bash
git add App/ZenWordOfDoom/LevelService.swift App/ZenWordOfDoomTests/LevelServiceTests.swift
git commit -m "feat(app): LevelService serves the Word of the Day puzzle for daily ids"
```

---

### Task 9: Solvability sweep for curated words

**Files:**
- Test: `Tests/LevelGenTests/WordOfTheDaySolvabilityTests.swift` (new)

**Interfaces:**
- Consumes: `WordOfTheDay.words(for:)` (Task 1), `GeneralWordList.shared.buildableWords(from:minLength:)` (existing, `Sources/LevelGen/GeneralWordList.swift`), `PackCatalog.pangramTarget(for:)`, `DifficultyBand(wheelSize:)`, `GameEngine.minWordLength` (existing, `Sources/GameCore/GameEngine.swift:52`).
- No new production code — this task is purely a correctness gate on Task 1's curated content.

- [ ] **Step 1: Write the test**

Create `Tests/LevelGenTests/WordOfTheDaySolvabilityTests.swift`:

```swift
import XCTest
import GameCore
@testable import LevelGen

/// Every curated Word-of-the-Day word must be *playable*: enough shorter
/// real words must be buildable from its letters to realistically reach its
/// Pangram-Hunt word-count target. This is the same invariant
/// `SolvabilitySweepTests` checks for procedurally generated levels, applied
/// to the hand-curated list instead — curation mistakes get caught here
/// rather than silently shipping an unwinnable bonus level.
final class WordOfTheDaySolvabilityTests: XCTestCase {
    func test_everyCuratedWordMeetsItsPangramTarget() {
        for theme in Theme.allCases {
            for word in WordOfTheDay.words(for: theme) {
                let multiset = LetterMultiset(Array(word))
                let target = PackCatalog.pangramTarget(for: DifficultyBand(wheelSize: word.count))
                let buildable = GeneralWordList.shared.buildableWords(from: multiset, minLength: GameEngine.minWordLength)
                // +1 because the pangram itself (the full word) counts toward
                // `foundWords`, but for words > 9 letters it can't appear in
                // the (3-9 letter) general corpus — don't double-require it.
                let effectiveCount = word.count <= 9 ? buildable.count : buildable.count + 1
                XCTAssertGreaterThanOrEqual(effectiveCount, target,
                    "\(word) (\(theme)): only \(buildable.count) buildable sub-words, needs \(target)")
            }
        }
    }
}
```

- [ ] **Step 2: Run the test**

Run: `swift test --filter WordOfTheDaySolvabilityTests`
Expected: PASS. If any word fails, the failure message names the exact word — replace that single word in `daily-zen.txt`/`daily-doom.txt` (Task 1's files) and its entry in `WordOfTheDayImages.swift`'s `byWord` map (Task 4) with another 8-10 letter real word of the same theme, then re-run this test and Tasks 1/2/4's tests to confirm nothing else broke.

- [ ] **Step 3: Commit**

```bash
git add Tests/LevelGenTests/WordOfTheDaySolvabilityTests.swift
git commit -m "test(levelgen): solvability sweep for curated Word of the Day words"
```

---

### Task 10: System-dictionary validation for all curated words

**Files:**
- Test: `App/ZenWordOfDoomTests/WordOfTheDayDictionaryTests.swift` (new)

**Interfaces:**
- Consumes: `WordOfTheDay.words(for:)` (Task 1), `SystemDictionary` (existing, `App/ZenWordOfDoom/SystemDictionary.swift`).
- No new production code — this validates 10-letter curated words (which the pure-package `GeneralWordList` structurally cannot check, since it's filtered to 3-9 letters) against the actual runtime dictionary `GameEngine.submit` uses.

- [ ] **Step 1: Write the test**

Create `App/ZenWordOfDoomTests/WordOfTheDayDictionaryTests.swift`:

```swift
import XCTest
import GameCore
import LevelGen
@testable import ZenWordOfDoom

/// Validates every curated Word-of-the-Day word against the real system
/// dictionary (`UITextChecker`, via `SystemDictionary`) — the exact
/// validator `GameEngine.submit` uses at runtime. This is the authoritative
/// "is it real" check for the 10-letter words, which the pure-package
/// `GeneralWordList` can't check (it's filtered to 3-9 letters).
final class WordOfTheDayDictionaryTests: XCTestCase {
    func testEveryCuratedWordIsARealDictionaryWord() {
        let dictionary = SystemDictionary()
        for theme in Theme.allCases {
            for word in WordOfTheDay.words(for: theme) {
                XCTAssertTrue(dictionary.isValidWord(word), "\(word) (\(theme)) failed system dictionary check")
            }
        }
    }
}
```

- [ ] **Step 2: Run the test**

Run: `xcodegen generate` then `xcodebuild -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ZenWordOfDoomTests/WordOfTheDayDictionaryTests | xcbeautify`
Expected: PASS. If any word fails, replace it (same procedure as Task 9 Step 2 — update `daily-zen.txt`/`daily-doom.txt` and `WordOfTheDayImages.swift` together) and re-run.

- [ ] **Step 3: Commit**

```bash
git add App/ZenWordOfDoomTests/WordOfTheDayDictionaryTests.swift
git commit -m "test(app): validate curated Word of the Day words against the system dictionary"
```

---

### Task 11: Extract `WheelLayout` with two-row stadium geometry

**Files:**
- Create: `App/ZenWordOfDoom/WheelLayout.swift`
- Test: `App/ZenWordOfDoomTests/WheelLayoutTests.swift` (new)

**Interfaces:**
- Produces: `struct WheelLayout { enum Shape { case circle, stadium }; let center: CGPoint, radius: CGFloat, count: Int, shape: Shape, tileSize: CGFloat, rowSpan: CGFloat, rowGap: CGFloat, curveDepth: CGFloat; func position(for index: Int) -> CGPoint; func row(for index: Int) -> Int; func arcControlPoint(from a: Int, to b: Int) -> CGPoint }` and a factory `WheelLayout.make(size:count:scaledTileSize:) -> WheelLayout` — Task 12 (`WheelView`) constructs and uses this instead of its current private nested struct.

This task is pure geometry (no SwiftUI) so it's testable without a simulator; Task 12 wires it into the actual view and needs a simulator visual check.

- [ ] **Step 1: Write the failing tests**

Create `App/ZenWordOfDoomTests/WheelLayoutTests.swift`:

```swift
import XCTest
@testable import ZenWordOfDoom

final class WheelLayoutTests: XCTestCase {
    private let size = CGSize(width: 360, height: 300)

    func testUnderEightTilesStaysCircle() {
        for count in 3...7 {
            let layout = WheelLayout.make(size: size, count: count, scaledTileSize: 56)
            XCTAssertEqual(layout.shape, .circle, "count \(count) should stay circle")
        }
    }

    func testEightOrMoreTilesIsStadium() {
        for count in 8...10 {
            let layout = WheelLayout.make(size: size, count: count, scaledTileSize: 56)
            XCTAssertEqual(layout.shape, .stadium, "count \(count) should be stadium")
        }
    }

    func testRowSplitEvenWithRemainderOnBottom() {
        // 8 -> 4+4, 9 -> 4+5, 10 -> 5+5 (top count = count/2, integer division).
        let expectations: [(count: Int, topCount: Int)] = [(8, 4), (9, 4), (10, 5)]
        for (count, expectedTop) in expectations {
            let layout = WheelLayout.make(size: size, count: count, scaledTileSize: 56)
            let topIndices = (0..<count).filter { layout.row(for: $0) == 0 }
            XCTAssertEqual(topIndices.count, expectedTop, "count \(count)")
        }
    }

    func testNoTwoTileCentersOverlapAcrossSizesAndCounts() {
        let sizes = [CGSize(width: 320, height: 260), CGSize(width: 360, height: 300), CGSize(width: 430, height: 350)]
        let tileSizes: [CGFloat] = [44, 56, 64, 80]
        for size in sizes {
            for tileSize in tileSizes {
                for count in 5...10 {
                    let layout = WheelLayout.make(size: size, count: count, scaledTileSize: tileSize)
                    let positions = (0..<count).map { layout.position(for: $0) }
                    for i in 0..<positions.count {
                        for j in (i + 1)..<positions.count {
                            let dx = positions[i].x - positions[j].x
                            let dy = positions[i].y - positions[j].y
                            let distance = (dx * dx + dy * dy).squareRoot()
                            XCTAssertGreaterThanOrEqual(
                                distance, layout.tileSize - 0.01,
                                "count \(count) tiles \(i)/\(j) overlap at size \(size), tileSize \(tileSize)")
                        }
                    }
                }
            }
        }
    }

    func testStadiumArcControlPointBendsTowardTheGapBetweenRows() {
        let layout = WheelLayout.make(size: size, count: 10, scaledTileSize: 56)
        // Two adjacent tiles in the top row (indices 0, 1 of a 5-tile top row).
        let p0 = layout.position(for: 0)
        let p1 = layout.position(for: 1)
        let control = layout.arcControlPoint(from: 0, to: 1)
        let straightMidY = (p0.y + p1.y) / 2
        // Top row's gap-ward direction is +y (down, toward the bottom row).
        XCTAssertGreaterThan(control.y, straightMidY, "top-row arc should bulge toward the center gap (down)")

        // Two adjacent tiles in the bottom row (last two indices).
        let b0 = layout.position(for: 8)
        let b1 = layout.position(for: 9)
        let bottomControl = layout.arcControlPoint(from: 8, to: 9)
        let bottomStraightMidY = (b0.y + b1.y) / 2
        XCTAssertLessThan(bottomControl.y, bottomStraightMidY, "bottom-row arc should bulge toward the center gap (up)")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodegen generate` then `xcodebuild -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ZenWordOfDoomTests/WheelLayoutTests | xcbeautify`
Expected: FAIL — `WheelLayout.make` doesn't exist yet (build error).

- [ ] **Step 3: Implement `WheelLayout`**

Create `App/ZenWordOfDoom/WheelLayout.swift`:

```swift
import CoreGraphics

/// Pure tile-position geometry for the letter wheel — no SwiftUI dependency,
/// so it's headlessly testable. Two shapes:
///
/// - `.circle` (under 8 tiles): the original evenly-spaced ring.
/// - `.stadium` (8+ tiles): two rows, each itself a shallow arc curving
///   *toward* the other row at its ends (so the whole shape reads as a
///   lens/stadium rather than two flat bars — confirmed via mockup review,
///   design spec §4.3). Row split is even with the remainder on the bottom
///   row (8->4+4, 9->4+5, 10->5+5).
struct WheelLayout: Equatable {
    enum Shape: Equatable { case circle, stadium }

    let center: CGPoint
    /// Meaningful for `.circle` only.
    let radius: CGFloat
    let count: Int
    let shape: Shape
    let tileSize: CGFloat
    /// Meaningful for `.stadium` only: horizontal half-width of each row.
    let rowSpan: CGFloat
    /// Meaningful for `.stadium` only: vertical distance between the two
    /// rows' baselines (before curvature pulls the edges closer together).
    let rowGap: CGFloat
    /// Meaningful for `.stadium` only: how far a row's edge tiles bow toward
    /// the other row, relative to its own baseline.
    let curveDepth: CGFloat

    /// Builds the layout for a given container size, tile count, and the
    /// view's `@ScaledMetric` tile size (before this layout's own cap is
    /// applied — stadium wheels use a tighter cap than the circle's, since
    /// more tiles need to fit in the same space).
    static func make(size: CGSize, count: Int, scaledTileSize: CGFloat) -> WheelLayout {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        if count >= 8 {
            let tile = min(max(scaledTileSize, 44), 64)
            let rowSpan = max(size.width / 2 - tile * 0.6, 0)
            return WheelLayout(center: center, radius: 0, count: count, shape: .stadium,
                               tileSize: tile, rowSpan: rowSpan, rowGap: tile * 1.5, curveDepth: tile * 0.2)
        } else {
            let tile = min(max(scaledTileSize, 44), 80)
            let radius = max(min(size.width, size.height) / 2 - tile * 0.64, 0)
            return WheelLayout(center: center, radius: radius, count: count, shape: .circle,
                               tileSize: tile, rowSpan: 0, rowGap: 0, curveDepth: 0)
        }
    }

    /// Which row (0 = top, 1 = bottom) a stadium position index belongs to.
    /// Meaningless for `.circle`.
    func row(for index: Int) -> Int {
        index < topCount ? 0 : 1
    }

    private var topCount: Int { count / 2 }

    func position(for index: Int) -> CGPoint {
        switch shape {
        case .circle:
            guard count > 0 else { return center }
            let angle = Double(index) / Double(count) * 2 * .pi - .pi / 2
            return CGPoint(x: center.x + radius * CGFloat(cos(angle)),
                           y: center.y + radius * CGFloat(sin(angle)))
        case .stadium:
            let top = topCount
            let isTop = index < top
            let rowCount = isTop ? top : count - top
            let posInRow = isTop ? index : index - top
            let normalizedX: Double = rowCount > 1
                ? (Double(posInRow) / Double(rowCount - 1)) * 2 - 1
                : 0
            let x = center.x + CGFloat(normalizedX) * rowSpan
            let sag = curveDepth * CGFloat(normalizedX * normalizedX)
            let y = isTop ? (center.y - rowGap / 2 + sag) : (center.y + rowGap / 2 - sag)
            return CGPoint(x: x, y: y)
        }
    }

    /// Control point for a curved same-row selection-trail segment: the
    /// straight-line midpoint, pulled toward the gap between the two rows
    /// (down for the top row, up for the bottom row) — the "arcs curving
    /// inward" confirmed via mockup review. Only meaningful for `.stadium`;
    /// callers only invoke this when `row(for:)` agrees for both endpoints.
    func arcControlPoint(from a: Int, to b: Int) -> CGPoint {
        let p1 = position(for: a), p2 = position(for: b)
        let mid = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
        let bulge = tileSize * 0.6
        let towardCenter: CGFloat = row(for: a) == 0 ? bulge : -bulge
        return CGPoint(x: mid.x, y: mid.y + towardCenter)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the same `xcodebuild ... -only-testing:ZenWordOfDoomTests/WheelLayoutTests` command as Step 2.
Expected: PASS (all 5 tests). `testNoTwoTileCentersOverlapAcrossSizesAndCounts` is the load-bearing one — it exercises the actual formulas across a size/tileSize/count grid, so a passing run is real evidence the stadium shape doesn't overlap, not just a hand-derived constant (contrast with the original circle's single hand-derived "9 tiles at 350pt" comment).

- [ ] **Step 5: Commit**

```bash
git add App/ZenWordOfDoom/WheelLayout.swift App/ZenWordOfDoomTests/WheelLayoutTests.swift
git commit -m "feat(app): extract WheelLayout with a two-row stadium shape for 8+ tiles"
```

---

### Task 12: Wire `WheelView` to `WheelLayout` and render inward same-row arcs

**Files:**
- Modify: `App/ZenWordOfDoom/WheelView.swift`

**Interfaces:**
- Consumes: `WheelLayout.make(size:count:scaledTileSize:)`, `.position(for:)`, `.row(for:)`, `.arcControlPoint(from:to:)`, `.tileSize`, `.shape` (Task 11).
- No new public interface — this is the view-layer wiring; `WheelView`'s own public interface (`tiles`, `displayOrder`, `selection`, callbacks) is unchanged.

- [ ] **Step 1: Remove the old private `WheelLayout` and `layout(in:count:)`, replace call sites**

In `App/ZenWordOfDoom/WheelView.swift`, delete the existing private `WheelLayout` struct and `layout(in:count:)` method (lines 117-136 per the pre-existing file), and replace every place that read the view's own `tileSize` with `layout.tileSize` instead, since tile size is now shape-dependent and lives on the `WheelLayout` value.

Replace the `body` implementation:

```swift
    var body: some View {
        let ordered = orderedTiles
        return GeometryReader { geo in
            let layout = WheelLayout.make(size: geo.size, count: ordered.count, scaledTileSize: scaledTileSize)
            ZStack {
                if layout.shape == .circle {
                    Circle()
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                        .frame(width: layout.radius * 2, height: layout.radius * 2)
                        .position(layout.center)
                }

                // The selection trail, drawn under the tiles so it threads
                // through them.
                trailPath(ordered: ordered, layout: layout)
                    .stroke(
                        Color.accentColor.opacity(0.85),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                    )
                    .allowsHitTesting(false)

                ForEach(Array(ordered.enumerated()), id: \.element.id) { index, tile in
                    TileView(
                        letter: tile.letter,
                        order: selectionOrder(of: tile.id),
                        isSelected: selection.contains(tile.id),
                        size: layout.tileSize
                    )
                    .position(layout.position(for: index))
                    .onTapGesture { onTap(tile.id) }
                    // VoiceOver activation paths alongside the tap/swipe
                    // gestures above: a named custom action always works,
                    // and the default activation action + isButton trait
                    // make a plain double-tap work too, in case the wheel's
                    // DragGesture ever intercepts the standard activation.
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { onTap(tile.id) }
                    .accessibilityAction(named: "Select \(tile.letter)") { onTap(tile.id) }
                    .accessibilityRespondsToUserInteraction(true)
                }
            }
            .contentShape(Rectangle())
            // High priority so the word-trace drag beats the enclosing
            // ScrollView's pan within the wheel's bounds — a plain .gesture
            // would lose swipes with a vertical component to the scroll.
            .highPriorityGesture(swipeGesture(ordered: ordered, layout: layout))
        }
        .frame(height: wheelHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Letter wheel")
        .accessibilityHint("Double-tap a letter to add it to the word. Use the Submit button to submit.")
    }
```

(Only change from the original: the ring `Circle()` now only draws for `.circle` shape — a stadium shape has no encircling ring — and every layout computation/tile sizing routes through the new `WheelLayout.make(...)`.)

- [ ] **Step 2: Update `trailPath` to curve same-row stadium segments inward**

Replace `trailPath`:

```swift
    /// A polyline through the centers of the selected tiles, in selection order,
    /// continuing to the finger while a drag is in progress. On a stadium wheel,
    /// a segment between two tiles in the *same* row curves inward toward the
    /// gap between rows (§4.3); every other segment (cross-row, or any segment
    /// on a circle wheel) stays a straight line, as before.
    private func trailPath(ordered: [LetterTile], layout: WheelLayout) -> Path {
        Path { path in
            let indices = selection.compactMap { id in ordered.firstIndex(where: { $0.id == id }) }
            guard let first = indices.first else { return }
            path.move(to: layout.position(for: first))
            for (prev, curr) in zip(indices, indices.dropFirst()) {
                let point = layout.position(for: curr)
                if layout.shape == .stadium, layout.row(for: prev) == layout.row(for: curr) {
                    path.addQuadCurve(to: point, control: layout.arcControlPoint(from: prev, to: curr))
                } else {
                    path.addLine(to: point)
                }
            }
            if isSwiping, let drag = dragLocation { path.addLine(to: drag) }
        }
    }
```

Remove the now-unused `position(ofTileID:ordered:layout:)` helper (its job — index lookup — is inlined into `trailPath` above via `ordered.firstIndex(where:)`), and the now-unused `WheelLayout` reference inside it.

- [ ] **Step 3: Update `tile(at:)` hit-testing to use `layout.tileSize`**

Replace the `tile(at:ordered:layout:)` method:

```swift
    /// Returns the id of the tile whose circular hit area contains `point`.
    private func tile(at point: CGPoint, ordered: [LetterTile], layout: WheelLayout) -> Int? {
        let hitRadius = layout.tileSize / 2
        for (index, tile) in ordered.enumerated() {
            let pos = layout.position(for: index)
            let dx = point.x - pos.x
            let dy = point.y - pos.y
            if (dx * dx + dy * dy) <= hitRadius * hitRadius {
                return tile.id
            }
        }
        return nil
    }
```

- [ ] **Step 4: Build and run the full app-target test suite**

Run: `xcodegen generate && xcodebuild -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' clean test CODE_SIGNING_ALLOWED=NO | xcbeautify`
Expected: BUILD SUCCEEDED, all existing tests still pass (this task has no new automated tests of its own — `WheelLayoutTests` from Task 11 already covers the geometry; this task is pure view wiring).

- [ ] **Step 5: Manual simulator visual check**

Launch the app in the simulator (Xcode Run, or `xcodebuild ... build` then boot/install manually), navigate to a Master-band level (9-tile wheel) and, once Task 13's images exist, the Daily bonus level for a 10-letter word. Confirm: (a) tiles don't visually overlap at the default text size and at the largest accessibility Dynamic Type size (Settings > Accessibility > Display & Text Size > Larger Text), and (b) dragging between two same-row letters visibly curves, dragging between a top and bottom letter stays straight. If tiles overlap at the largest accessibility size, lower the stadium tile-size cap in `WheelLayout.make` (currently 64) and re-run Task 11's `testNoTwoTileCentersOverlapAcrossSizesAndCounts` plus this manual check.

- [ ] **Step 6: Commit**

```bash
git add App/ZenWordOfDoom/WheelView.swift
git commit -m "feat(app): render the two-row stadium wheel with inward-arcing same-row trails"
```

---

### Task 13: Offline image authoring via `agy`

**Files:**
- Create: `scripts/generate-daily-word-images.sh`

**Interfaces:**
- Consumes: `VisualPrompts.prompt(forSceneID:theme:)` (Task 5) for the 24 slug prompts; writes into `App/ZenWordOfDoom/Assets.xcassets/scene-<slug>.imageset/` (the naming convention Task 6 registered).
- Produces: 24 populated imagesets (`Contents.json` + a `.jpg`/`.png`), matching the existing `scene-still-pond.imageset` structure — no code interface, this is a one-time content-generation step.

- [ ] **Step 1: Spike — confirm `agy` can save an image file from a prompt**

Before writing the batch script, manually verify the exact invocation with **one** slug:

```bash
agy -p "Generate an illustration image for this description and save it as a PNG file to /tmp/agy-spike-test.png: a warm golden sunrise breaking over still hills, soft light, calm illustration" --dangerously-skip-permissions
ls -la /tmp/agy-spike-test.png
file /tmp/agy-spike-test.png
```

Expected: a valid image file exists at that path (`file` reports an image format, not text/HTML/error). If `agy`'s actual behavior differs (e.g. it writes to a different path, or needs a different phrasing to trigger its image tool), adjust the prompt template in Step 2 to match what actually works before proceeding — do not write the full batch script against an unverified assumption.

- [ ] **Step 2: Write the batch script**

Create `scripts/generate-daily-word-images.sh`:

```bash
#!/bin/sh
# Generates the 24 Word-of-the-Day illustration slugs via the `agy`
# (Antigravity) CLI and installs each into Assets.xcassets, following the
# existing bundled-visuals convention (scene-<slug>.imageset/<slug>.jpg +
# Contents.json). Idempotent: re-running skips any slug that already has a
# bundled image, so a throttled run can simply be resumed later. Paced with
# a delay between calls since `agy` has usage limits.
set -eu

cd "$(dirname "$0")/.."
ASSETS_DIR="App/ZenWordOfDoom/Assets.xcassets"
DELAY_SECONDS=15
MAX_RETRIES=3

# slug|theme|prompt — one line per Word-of-the-Day illustration slug (Task 5's
# VisualPrompts entries, duplicated here as plain data since this script has
# no Swift runtime to read VisualPrompts.swift from).
SLUGS='
dawn-glow|zen|a warm golden sunrise breaking over still hills, soft light, calm illustration
moonlit-hush|zen|a pale full moon over quiet rooftops, soft blue light, calm illustration
still-water|zen|a calm mountain lake at dawn reflecting distant peaks, soft mist, serene illustration
quiet-garden|zen|a blooming garden of pale flowers in gentle morning light, calm illustration
lantern-calm|zen|a quiet mountain path lit by paper lanterns at dusk, peaceful illustration
gentle-breath|zen|a figure meditating cross-legged under a soft glowing sky, calm watercolor illustration
drifting-ease|zen|a single leaf drifting slowly down a gentle stream, soft pastel illustration
warm-heart|zen|sunlight filtering through orchard branches onto a quiet path, warm calm illustration
nurtured-soul|zen|a quiet tide pool with a single seashell at dawn, soft pastel illustration
calm-balance|zen|a smooth stack of balanced stones on a still shoreline, soft light, calm illustration
soft-whisper|zen|wind gently stirring tall grass under a twilight sky, soft illustration
graceful-harmony|zen|a slow waterfall over mossy stones in soft dappled light, serene illustration
ashen-ruin|doom|crumbling stone ruins under an ash-grey sky, faint eerie glow, ominous stylized illustration
black-crypt|doom|a collapsing underground crypt lit by a single dim torch, ominous stylized illustration
cursed-hollow|doom|a twisted dead forest hollow under a bruised sky, eerie stylized illustration
gravebound|doom|an overgrown forgotten graveyard gate at dusk, cold light, ominous stylized illustration
festering-dark|doom|a decaying stone archway dripping with moss, sickly green glow, stylized illustration
shrieking-night|doom|a jagged mountain pass under a blood-red moon, ominous stylized illustration
monstrous-thing|doom|a hulking shadowed silhouette looming behind fog, deep violet glow, stylized illustration
forsaken-tomb|doom|an abandoned stone tomb sealed shut with old chains, cold blue glow, stylized illustration
venomous-rite|doom|a ring of dark candles around a cracked stone altar, eerie glow, stylized illustration
spectral-dread|doom|a pale spectral shape drifting through a ruined hall, cold light, stylized illustration
ravaged-earth|doom|a cracked and scorched battlefield under a smoky sky, ominous stylized illustration
malevolent-omen|doom|a single glowing red eye watching from deep shadow, stylized, ominous illustration
'

echo "$SLUGS" | while IFS='|' read -r slug theme prompt; do
  [ -z "$slug" ] && continue
  imageset_dir="$ASSETS_DIR/scene-$slug.imageset"
  image_path="$imageset_dir/$slug.png"

  if [ -s "$image_path" ]; then
    echo "skip $slug (already generated)"
    continue
  fi

  mkdir -p "$imageset_dir"
  attempt=1
  while [ "$attempt" -le "$MAX_RETRIES" ]; do
    echo "generating $slug (attempt $attempt/$MAX_RETRIES)..."
    if agy -p "Generate an illustration image for this description and save it as a PNG file to $PWD/$image_path: $prompt" --dangerously-skip-permissions; then
      if [ -s "$image_path" ]; then
        break
      fi
    fi
    echo "  retry after throttle/failure..."
    attempt=$((attempt + 1))
    sleep "$DELAY_SECONDS"
  done

  if [ ! -s "$image_path" ]; then
    echo "FAILED to generate $slug after $MAX_RETRIES attempts — re-run this script later to retry" >&2
    exit 1
  fi

  cat > "$imageset_dir/Contents.json" << EOF
{
  "images" : [
    {
      "filename" : "$slug.png",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

  echo "done $slug"
  sleep "$DELAY_SECONDS"
done

echo "All 24 Word-of-the-Day images generated."
```

Make it executable: `chmod +x scripts/generate-daily-word-images.sh`

- [ ] **Step 3: Run the script**

Run: `./scripts/generate-daily-word-images.sh`

Expected: all 24 slugs report `done <slug>`, ending with "All 24 Word-of-the-Day images generated." If it exits early with a `FAILED` line (throttled past `MAX_RETRIES`), simply re-run the script later — completed slugs are skipped, so it resumes where it left off.

- [ ] **Step 4: Verify every imageset is valid**

```bash
for d in App/ZenWordOfDoom/Assets.xcassets/scene-*.imageset; do
  slug=$(basename "$d" .imageset | sed 's/^scene-//')
  case "$slug" in
    dawn-glow|moonlit-hush|still-water|quiet-garden|lantern-calm|gentle-breath|drifting-ease|warm-heart|nurtured-soul|calm-balance|soft-whisper|graceful-harmony|ashen-ruin|black-crypt|cursed-hollow|gravebound|festering-dark|shrieking-night|monstrous-thing|forsaken-tomb|venomous-rite|spectral-dread|ravaged-earth|malevolent-omen)
      test -f "$d/Contents.json" && test -s "$d/$slug.png" && echo "ok $slug" || echo "MISSING $slug"
      ;;
  esac
done
```

Expected: `ok <slug>` for all 24 — no `MISSING` lines.

- [ ] **Step 5: Run the full app-target suite once more to confirm the bundled art resolves**

Run: `xcodegen generate && xcodebuild -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' clean test CODE_SIGNING_ALLOWED=NO | xcbeautify`
Expected: BUILD SUCCEEDED, all tests pass (Task 6's `testEveryWordOfTheDaySlugHasBundledAsset` was already passing on the name-mapping alone; this run additionally exercises the real asset catalog with the new images present).

- [ ] **Step 6: Commit**

```bash
git add scripts/generate-daily-word-images.sh "App/ZenWordOfDoom/Assets.xcassets/scene-dawn-glow.imageset" \
        "App/ZenWordOfDoom/Assets.xcassets/scene-moonlit-hush.imageset" "App/ZenWordOfDoom/Assets.xcassets/scene-still-water.imageset" \
        "App/ZenWordOfDoom/Assets.xcassets/scene-quiet-garden.imageset" "App/ZenWordOfDoom/Assets.xcassets/scene-lantern-calm.imageset" \
        "App/ZenWordOfDoom/Assets.xcassets/scene-gentle-breath.imageset" "App/ZenWordOfDoom/Assets.xcassets/scene-drifting-ease.imageset" \
        "App/ZenWordOfDoom/Assets.xcassets/scene-warm-heart.imageset" "App/ZenWordOfDoom/Assets.xcassets/scene-nurtured-soul.imageset" \
        "App/ZenWordOfDoom/Assets.xcassets/scene-calm-balance.imageset" "App/ZenWordOfDoom/Assets.xcassets/scene-soft-whisper.imageset" \
        "App/ZenWordOfDoom/Assets.xcassets/scene-graceful-harmony.imageset" "App/ZenWordOfDoom/Assets.xcassets/scene-ashen-ruin.imageset" \
        "App/ZenWordOfDoom/Assets.xcassets/scene-black-crypt.imageset" "App/ZenWordOfDoom/Assets.xcassets/scene-cursed-hollow.imageset" \
        "App/ZenWordOfDoom/Assets.xcassets/scene-gravebound.imageset" "App/ZenWordOfDoom/Assets.xcassets/scene-festering-dark.imageset" \
        "App/ZenWordOfDoom/Assets.xcassets/scene-shrieking-night.imageset" "App/ZenWordOfDoom/Assets.xcassets/scene-monstrous-thing.imageset" \
        "App/ZenWordOfDoom/Assets.xcassets/scene-forsaken-tomb.imageset" "App/ZenWordOfDoom/Assets.xcassets/scene-venomous-rite.imageset" \
        "App/ZenWordOfDoom/Assets.xcassets/scene-spectral-dread.imageset" "App/ZenWordOfDoom/Assets.xcassets/scene-ravaged-earth.imageset" \
        "App/ZenWordOfDoom/Assets.xcassets/scene-malevolent-omen.imageset"
git commit -m "feat(app): generate and bundle the 24 Word of the Day illustrations"
```

---

### Task 14: Final regression pass

**Files:** none (verification only)

**Interfaces:** none — this task runs the full existing suites to confirm nothing in Tasks 1-13 regressed unrelated behavior.

- [ ] **Step 1: Run the full Swift package test suite**

Run: `swift test`
Expected: all tests pass, including every pre-existing `LevelGenTests`/`GameCoreTests` file untouched by this plan (e.g. `SolvabilitySweepTests`, `ProceduralLevelLibraryTests`, `PackCatalogTests`).

- [ ] **Step 2: Run the full app-target test suite**

Run: `xcodegen generate && xcodebuild -project ZenWordOfDoom.xcodeproj -scheme ZenWordOfDoom -destination 'platform=iOS Simulator,name=iPhone 17' clean test CODE_SIGNING_ALLOWED=NO | xcbeautify`
Expected: BUILD SUCCEEDED, all tests pass, including `GameViewModelTests`, `GameStoreTests`, `GridAccessibilityTests`, `WCAGContrastTests`, `ConsentGateTests` (all pre-existing, untouched by this plan).

- [ ] **Step 3: Confirm the bonus/skippable requirement manually**

Launch the app in the simulator, open the Daily card from the menu, and confirm: (a) the wheel shows the two-row stadium shape with the word's bundled illustration as the background, (b) backing out to level-select and picking any other (non-daily) level works exactly as before — the daily puzzle being incomplete has no visible effect on it.

No commit for this task — it's a verification gate before handing off to review/merge.
