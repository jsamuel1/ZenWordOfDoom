import Foundation

/// The single price list. Every serenity faucet and sink reads from here —
/// tuned against the serenity IAP sizes (45/100/220) so purchases matter
/// without becoming pay-to-win.
///
/// Design target: earned income of roughly **0.8 hints per level** averaged
/// over a pack of 10, boss bonus included. A clean pack yields about
/// 9 × (2 clear + ~1.5 capped bonus words) + (2 + 50 boss + 2 bonus) ≈ 84
/// serenity ≈ 8.4/level against the 10-serenity hint.
public enum Economy {
    public static let hintCost = 10
    public static let bonusWordReward = 1

    /// At most this many bonus words pay serenity per level (lifetime, while
    /// the level is uncleared) — keeps the per-level yield near the design
    /// target and stops long bonus hunts (or boss word lists, where every
    /// word is a "bonus") from flooding the faucet.
    public static let maxBonusRewardsPerLevel = 2

    /// A fresh profile's opening balance — enough for a few early hints so
    /// new players learn the mechanic before serenity gets scarce.
    public static let startingSerenity = 50

    /// Flat bonus for the first clear of a pack-capstone boss (Pangram-Hunt).
    /// Never score- or doom-timer-multiplied — the multiplier is points-only.
    /// This is deliberately the pack's payday: half a pack's income lands on
    /// the boss beat.
    public static let bossClearReward = 50

    /// Serenity for clearing a level. Voided (doom-expired) clears pay nothing.
    public static func clearReward(firstClear: Bool, usedHint: Bool, voided: Bool) -> Int {
        guard !voided, firstClear else { return 0 }
        return usedHint ? 1 : 2   // 1 base + 1 no-hint bonus
    }
}
