import Foundation

/// Raw input events produced by any input method (swipe, tap, voice).
public enum TileInputEvent: Equatable, Sendable {
    case begin(tileID: Int)
    case extend(tileID: Int)
    case backtrack
    case submit
    case cancel
}

/// Accumulates an ordered tile selection from input events. The same builder
/// serves swipe, tap, and voice — they differ only in how gestures map here.
public final class WordBuilder {
    public private(set) var selection: [Int] = []

    public init() {}

    /// Apply an event. Returns the finished tile-id sequence on `.submit`
    /// (and clears state); otherwise returns nil.
    @discardableResult
    public func apply(_ event: TileInputEvent) -> [Int]? {
        switch event {
        case .begin(let id):
            selection = [id]
        case .extend(let id):
            // Tapping/dragging the most recent tile again removes it.
            if selection.last == id {
                selection.removeLast()
            } else if !selection.contains(id) {
                selection.append(id)
            }
        case .backtrack:
            if !selection.isEmpty { selection.removeLast() }
        case .cancel:
            selection = []
        case .submit:
            let result = selection
            selection = []
            return result.isEmpty ? nil : result
        }
        return nil
    }

    /// The word currently spelled by `selection`, given a wheel.
    public func currentWord(on wheel: Wheel) -> String {
        let byID = Dictionary(uniqueKeysWithValues: wheel.tiles.map { ($0.id, $0.letter) })
        return String(selection.compactMap { byID[$0] })
    }
}
