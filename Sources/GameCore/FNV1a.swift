import Foundation

/// The project's single FNV-1a hash. Deterministic across launches, devices,
/// and app versions — used for wheel seeds, hint-reveal order, and the daily
/// puzzle. Never use `String.hashValue` for anything persisted or replayable.
public enum FNV1a {
    public static func hash(_ text: String) -> UInt64 {
        var h: UInt64 = 14_695_981_039_346_656_037
        for b in text.utf8 { h = (h ^ UInt64(b)) &* 1_099_511_628_211 }
        return h
    }
}
