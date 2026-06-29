import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Lightweight wrappers over UIKit feedback generators. Safe to call from
/// anywhere on the main actor; on platforms without UIKit these are no-ops.
///
/// Each call creates and fires a generator immediately. This is fine for the
/// occasional, discrete feedback events the game emits (tap, success, reveal);
/// we trade the tiny cost of allocation for not having to manage shared
/// generator lifetime/`prepare()` state in a stateless utility.
enum Haptics {
    /// A light selection tick for tapping or selecting a tile.
    static func tap() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    /// A success notification for solving a slot or completing a level.
    static func success() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    /// A medium impact for revealing a hint cell or a doom pop-out.
    static func reveal() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
}
