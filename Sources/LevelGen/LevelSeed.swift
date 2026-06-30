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
