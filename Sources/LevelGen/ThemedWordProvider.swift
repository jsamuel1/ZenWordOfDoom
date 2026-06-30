import GameCore

/// Supplies candidate themed words for a wheel. Deterministic (corpus) now;
/// a Foundation Models implementation is added in a later phase.
public protocol ThemedWordProvider: Sendable {
    func words(forWheel wheel: Wheel, theme: Theme, limit: Int) async throws -> [String]
}
