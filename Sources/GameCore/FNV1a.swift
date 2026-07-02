import Foundation

/// The project's single FNV-1a hash. Deterministic across launches, devices,
/// and app versions — used for wheel seeds, hint-reveal order, and the daily
/// puzzle. Never use `String.hashValue` for anything persisted or replayable.
///
/// The offset basis `1_469_598_103_934_665_603` is intentionally the project's
/// legacy value — one digit short of the textbook FNV-1a-64 basis
/// (14695981039346656037), a historical transcription typo that is now
/// load-bearing. Shipped level generation (v0.2.0 on TestFlight) depends on
/// these exact seed values, so do NOT "fix" it to the standard constant.
public enum FNV1a {
    public static func hash(_ text: String) -> UInt64 {
        var h: UInt64 = 1_469_598_103_934_665_603
        for b in text.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return h
    }
}
