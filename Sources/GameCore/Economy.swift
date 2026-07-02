import Foundation

/// The single price list. Every serenity faucet and sink reads from here —
/// tuned against the serenity IAP sizes (10/25/50) so purchases matter
/// without becoming pay-to-win (~2-3 earned hints per pack).
public enum Economy {
    public static let hintCost = 10
    public static let bonusWordReward = 1

    /// Serenity for clearing a level. Voided (doom-expired) clears pay nothing.
    public static func clearReward(firstClear: Bool, usedHint: Bool, voided: Bool) -> Int {
        guard !voided, firstClear else { return 0 }
        return usedHint ? 5 : 8   // 5 base + 3 no-hint bonus
    }
}
