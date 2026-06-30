# Foundation Models Word Provider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Use iOS 26 Foundation Models on-device to generate the themed word pool for each level, with the deterministic corpus provider as a guaranteed fallback + top-up, cached per wheel so levels stay stable and fast.

**Architecture:** `FoundationModelsWordProvider` is a **decorator** over `DeterministicWordProvider`: it always computes the deterministic pool as a floor, and — when Apple Intelligence is available — asks Foundation Models for themed candidates, hard-filters them (buildable from the wheel + real via `SystemDictionary`), merges them ahead of the deterministic top-up, and caches the result to disk. When AI is unavailable (most devices, the simulator, CI), it returns the deterministic pool unchanged. The merge/filter logic is a pure, tested helper in `LevelGen`. `ProceduralGenerator` is unchanged — it just receives a provider that always returns a solvable pool.

**Tech Stack:** Swift 5.9, `FoundationModels` framework (`SystemLanguageModel`, `LanguageModelSession`, `@Generable`), the `LevelGen`/`GameCore` packages, `SystemDictionary` (UITextChecker).

**Spec:** [`procedural-level-generation-design.md`](../specs/2026-06-30-procedural-level-generation-design.md) §5 (pipeline), §8 (availability/latency — the themed loader from Plan 1b already hides FM latency), §9 (correctness: the LLM is never trusted; filters enforce real+buildable).

**Verification:**
- LevelGen task (1): `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test`
- App tasks (2–3): `xcodegen generate` then
  ```
  DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
    xcodebuild -scheme ZenWordOfDoom \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -derivedDataPath .build/xcode build CODE_SIGNING_ALLOWED=NO | tail -20
  ```
  Expect `** BUILD SUCCEEDED **`. The simulator has no Apple Intelligence, so the **deterministic path runs** — that's expected and correct. (Adapt the Xcode path / sim name if needed.)

---

## Task 1: WordPoolBuilder.merge (pure, in LevelGen)

**Files:** Create `Sources/LevelGen/WordPoolBuilder.swift`; Test `Tests/LevelGenTests/WordPoolBuilderTests.swift`.

Merges model candidates with the deterministic fallback. **Model candidates are validated** (buildable + real); **fallback words are trusted** (already corpus-real) and only buildability-checked, so the guaranteed floor is never shrunk by `UITextChecker` not knowing a corpus word.

- [ ] **Step 1 — failing test:**
```swift
import XCTest
import GameCore
@testable import LevelGen

private struct StubValidator: WordValidating {
    let valid: Set<String>
    func isValidWord(_ word: String) -> Bool { valid.contains(word.uppercased()) }
}

final class WordPoolBuilderTests: XCTestCase {
    private let wheel = Wheel(letters: "STONE")  // S,T,O,N,E

    func testKeepsBuildableRealModelWordsThenFallback() {
        let out = WordPoolBuilder.merge(
            primary: ["STONE", "NOTES", "ZZZZZ", "QI"],   // STONE/NOTES ok; ZZZZZ not buildable; QI too short
            fallback: ["TONES", "ONES"],
            wheel: wheel,
            validator: StubValidator(valid: ["STONE", "NOTES"]),
            limit: 10, minLength: 3)
        XCTAssertEqual(out, ["STONE", "NOTES", "TONES", "ONES"])
    }
    func testModelWordRejectedWhenNotValidEvenIfBuildable() {
        let out = WordPoolBuilder.merge(
            primary: ["SNOT"],                 // buildable but validator says not real
            fallback: ["NOTE"],
            wheel: wheel,
            validator: StubValidator(valid: ["NOTE"]),
            limit: 10)
        XCTAssertEqual(out, ["NOTE"])          // SNOT dropped; fallback kept (not re-validated)
    }
    func testFallbackNotRevalidated() {
        // Fallback word the validator would reject is still kept (trusted corpus).
        let out = WordPoolBuilder.merge(
            primary: [], fallback: ["ONSET"],
            wheel: Wheel(letters: "ONSETX"),
            validator: StubValidator(valid: []),
            limit: 10)
        XCTAssertEqual(out, ["ONSET"])
    }
    func testDedupCaseInsensitiveAndCap() {
        let out = WordPoolBuilder.merge(
            primary: ["stone", "STONE"], fallback: ["notes", "tones", "ones"],
            wheel: wheel, validator: StubValidator(valid: ["STONE"]),
            limit: 2)
        XCTAssertEqual(out, ["STONE", "NOTES"])  // dedup STONE, cap at 2
    }
    func testEmptyPrimaryYieldsFallback() {
        let out = WordPoolBuilder.merge(
            primary: [], fallback: ["NOTE", "TONE"],
            wheel: wheel, validator: StubValidator(valid: []), limit: 10)
        XCTAssertEqual(out, ["NOTE", "TONE"])
    }
}
```
- [ ] **Step 2 — run, watch fail.**
- [ ] **Step 3 — implement `WordPoolBuilder.swift`:**
```swift
import GameCore

/// Builds a level's word pool from model-proposed candidates plus a trusted
/// deterministic fallback. The model is never trusted for correctness: its words
/// must be buildable from the wheel AND pass the validator. Fallback words are
/// already corpus-real, so they are only buildability-checked.
public enum WordPoolBuilder {
    public static func merge(
        primary: [String],
        fallback: [String],
        wheel: Wheel,
        validator: any WordValidating,
        limit: Int,
        minLength: Int = 3
    ) -> [String] {
        let multiset = wheel.multiset
        func clean(_ words: [String], validate: Bool) -> [String] {
            words.compactMap { raw in
                let w = raw.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard w.count >= minLength, multiset.canBuild(w) else { return nil }
                if validate, !validator.isValidWord(w) { return nil }
                return w
            }
        }
        var seen = Set<String>()
        var result: [String] = []
        for w in clean(primary, validate: true) + clean(fallback, validate: false) {
            guard seen.insert(w).inserted else { continue }
            result.append(w)
            if result.count >= limit { break }
        }
        return result
    }
}
```
- [ ] **Step 4 — run filtered then full `swift test`; green.**
- [ ] **Step 5 — commit:** `feat(levelgen): WordPoolBuilder merges model words with trusted fallback`.

---

## Task 2: FoundationModelsWordProvider + word-pool cache

**Files:** Create `App/ZenWordOfDoom/WordPoolCache.swift`, `App/ZenWordOfDoom/FoundationModelsWordProvider.swift`.

**FIRST — API probe** (like the Image Playground task). Confirm `import FoundationModels`, `SystemLanguageModel`, `LanguageModelSession`, and guided generation (`@Generable`/`@Guide`, `session.respond(to:generating:)`) compile against this SDK. Inspect the framework `.swiftinterface` for the real names if unsure. **If `FoundationModels` is unavailable, STOP and report BLOCKED** — Task 1 still merges, and the app keeps using `DeterministicWordProvider`; nothing else changes. Do not force a workaround.

### 2a. `WordPoolCache.swift` — disk cache of `[String]` per wheel/theme:
```swift
import Foundation
import GameCore
import LevelGen

/// Disk cache of generated word pools, keyed by theme + wheel letters, so a
/// level's Foundation-Models pool is generated once and reused. Disposable.
struct WordPoolCache {
    static let shared = WordPoolCache()
    static let version = 1
    private let dir: URL

    init() {
        let base = (try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        dir = base.appendingPathComponent("wordpools", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func key(wheel: Wheel, theme: Theme) -> String {
        let letters = wheel.tiles.map { String($0.letter) }.sorted().joined()
        return "\(theme.rawValue)-\(letters)-v\(Self.version)"
    }
    private func url(_ key: String) -> URL { dir.appendingPathComponent(key + ".json") }

    func pool(wheel: Wheel, theme: Theme) -> [String]? {
        guard let data = try? Data(contentsOf: url(key(wheel: wheel, theme: theme))) else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }
    func store(_ pool: [String], wheel: Wheel, theme: Theme) {
        guard let data = try? JSONEncoder().encode(pool) else { return }
        try? data.write(to: url(key(wheel: wheel, theme: theme)), options: [.atomic])
    }
}
```

### 2b. `FoundationModelsWordProvider.swift` — adapt to the REAL FM API:
```swift
import Foundation
import FoundationModels
import GameCore
import LevelGen

/// ThemedWordProvider backed by on-device Foundation Models, decorating the
/// deterministic provider. Always returns a solvable pool: the deterministic
/// result is the floor; FM themed candidates (hard-filtered to real + buildable)
/// are merged ahead of it when Apple Intelligence is available. Cached per wheel.
struct FoundationModelsWordProvider: ThemedWordProvider {
    private let fallback = DeterministicWordProvider()
    private let validator = SystemDictionary()

    func words(forWheel wheel: Wheel, theme: Theme, limit: Int) async throws -> [String] {
        let floor = try await fallback.words(forWheel: wheel, theme: theme, limit: limit)

        // Availability: only call FM when the system model is ready.
        guard case .available = SystemLanguageModel.default.availability else { return floor }
        if let cached = WordPoolCache.shared.pool(wheel: wheel, theme: theme) { return cached }

        let candidates = (try? await generate(wheel: wheel, theme: theme, limit: limit)) ?? []
        let merged = WordPoolBuilder.merge(primary: candidates, fallback: floor,
                                           wheel: wheel, validator: validator, limit: limit)
        let pool = merged.isEmpty ? floor : merged
        WordPoolCache.shared.store(pool, wheel: wheel, theme: theme)
        return pool
    }

    // Guided generation. Adapt the @Generable type and respond(...) call to the SDK.
    @Generable
    private struct WordList {
        @Guide(description: "Real English dictionary words, 3 to 9 letters, uppercase")
        let words: [String]
    }

    private func generate(wheel: Wheel, theme: Theme, limit: Int) async throws -> [String] {
        let letters = wheel.tiles.map { String($0.letter) }.joined()
        let flavor = theme == .zen
            ? "calm, serene, nature and meditation themed"
            : "ominous and gothic: dread, the occult, monsters, eldritch horror, graveyards"
        let prompt = """
        Letters available: \(letters).
        List up to \(limit) real English dictionary words, each 3-9 letters, that can be \
        spelled using ONLY those letters (each letter used no more times than it appears). \
        Prefer \(flavor) words. Only real words. No proper nouns, no names, no made-up words.
        """
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt, generating: WordList.self)
        return response.content.words
    }
}
```
Notes for adapting to the real API:
- `SystemLanguageModel.default.availability` may be an enum with `.available` and `.unavailable(...)`. Match `.available` correctly.
- The guided call may be `session.respond(to:generating:)` returning a response whose payload is `.content` (a `WordList`), or a slightly different shape — adapt to extract `[String]`. If guided generation isn't available, fall back to a plain string `respond(to:)` and split the text into words; still hard-filtered downstream, so correctness holds.
- Wrap the FM call so any throw/timeout just yields `[]` (caller already has the floor). Consider `withTimeout`-style cancellation if easily available; otherwise rely on the floor.
- Keep the type `Sendable`-clean (struct with value members). Create the session per call.

- [ ] **Step 1 — probe FM API; if unavailable, report BLOCKED (keep DeterministicWordProvider).**
- [ ] **Step 2 — implement 2a + 2b**, adapting to the confirmed API.
- [ ] **Step 3 — build** → `** BUILD SUCCEEDED **` (compiles; simulator → availability not `.available` → returns floor). `swift test` packages green.
- [ ] **Step 4 — commit:** `feat(app): Foundation Models word provider with deterministic fallback`.

---

## Task 3: Wire the FM provider into the app

**Files:** Modify `App/ZenWordOfDoom/LevelService.swift` (or `ZenWordOfDoomApp.swift`).

`LevelService.init(wordProvider:)` defaults to `DeterministicWordProvider()`. Make the app use the FM provider (which itself falls back to deterministic).

- [ ] **Step 1 —** change the default in `LevelService.init` to `FoundationModelsWordProvider()`:
  `init(wordProvider: any ThemedWordProvider = FoundationModelsWordProvider())`.
  (LevelService is in the app target, so it can reference the app-target FM provider. If a layering issue arises, instead construct `LevelService(wordProvider: FoundationModelsWordProvider())` at the app root in `ZenWordOfDoomApp.swift` and leave the default as-is.)
- [ ] **Step 2 — build** → BUILD SUCCEEDED. On the simulator the deterministic floor runs (identical levels to today); on an Apple-Intelligence device the FM-enriched, cached pool is used, hidden behind Plan 1b's themed loader.
- [ ] **Step 3 — commit:** `feat(app): use Foundation Models word provider for level generation`.

---

## Final review

Dispatch a holistic review (focus: the FM availability gate + the guarantee that an unsolvable/empty pool is impossible because the deterministic floor is always returned; that the LLM is never trusted — every model word is buildable+validated; cache correctness; Sendable/concurrency of the provider; that the simulator/CI path is the deterministic floor). Confirm `swift test` + app build green, then finish the branch (merge to `main`) via superpowers:finishing-a-development-branch.

**If Task 2 is BLOCKED** (no `FoundationModels` in the SDK): Task 1 still merges (the pure merge helper is ready), and the app keeps using `DeterministicWordProvider`; record the blocker in the merge notes and revisit when the framework is available.
