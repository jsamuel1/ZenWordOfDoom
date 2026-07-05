import Foundation

/// The single price list. Every serenity faucet and sink reads from here —
/// tuned against the serenity IAP sizes (45/100/220) so purchases matter
/// without becoming pay-to-win.
public enum Economy {
    public static let hintCost = 10
    public static let bonusWordReward = 1

    /// A fresh profile's opening balance — enough for a few early hints so
    /// new players learn the mechanic before serenity gets scarce.
    public static let startingSerenity = 50

    /// Flat bonus for the first clear of a pack-capstone boss (Pangram-Hunt).
    /// Never score- or doom-timer-multiplied — the multiplier is points-only.
    public static let bossClearReward = 50

    /// Serenity for clearing a level. Voided (doom-expired) clears pay nothing.
    public static func clearReward(firstClear: Bool, usedHint: Bool, voided: Bool) -> Int {
        guard !voided, firstClear else { return 0 }
        return usedHint ? 5 : 8   // 5 base + 3 no-hint bonus
    }
}
