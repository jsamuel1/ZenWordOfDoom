import Foundation
import UIKit
import GameCore

/// Validates words against iOS's built-in dictionary via `UITextChecker` — the
/// same dictionary that powers system spell-check. A word is "real" when the
/// system spell-checker finds no misspelling.
///
/// This lives in the app target (not `WordEngine`) because `UITextChecker` is a
/// UIKit/iOS API; the pure-Swift cores stay platform-agnostic and headlessly
/// testable.
struct SystemDictionary: WordValidating {
    /// Best available English language for the checker, resolved once.
    private static let language: String = {
        let available = UITextChecker.availableLanguages
        return available.first { $0 == "en_US" }
            ?? available.first { $0.hasPrefix("en") }
            ?? "en_US"
    }()

    func isValidWord(_ word: String) -> Bool {
        // Lowercase first: UITextChecker treats an all-uppercase token as an
        // acronym and skips spell-checking it (so "XQZ" would falsely pass).
        // Wheel words arrive uppercased, so normalize for a real check.
        let candidate = word
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !candidate.isEmpty else { return false }

        let checker = UITextChecker()
        let range = NSRange(location: 0, length: candidate.utf16.count)
        let misspelled = checker.rangeOfMisspelledWord(
            in: candidate,
            range: range,
            startingAt: 0,
            wrap: false,
            language: Self.language
        )
        return misspelled.location == NSNotFound
    }
}
