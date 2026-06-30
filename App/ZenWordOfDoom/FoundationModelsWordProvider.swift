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
        guard case .available = SystemLanguageModel.default.availability else { return floor }
        if let cached = WordPoolCache.shared.pool(wheel: wheel, theme: theme) { return cached }

        let candidates = (try? await generate(wheel: wheel, theme: theme, limit: limit)) ?? []
        let merged = WordPoolBuilder.merge(primary: candidates, fallback: floor,
                                           wheel: wheel, validator: validator, limit: limit)
        let pool = merged.isEmpty ? floor : merged
        WordPoolCache.shared.store(pool, wheel: wheel, theme: theme)
        return pool
    }

    @Generable
    struct WordList {
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
