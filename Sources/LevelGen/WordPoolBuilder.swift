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
