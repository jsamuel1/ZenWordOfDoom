import Foundation
import GameCore

/// A tiny built-in word list so the app and tests run before a full,
/// license-cleared dictionary is bundled (see docs/SPEC.md §13).
public enum SampleWords {
    public static let list: [String] = [
        // buildable from STONED — used by the sample level
        "STONE", "STONED", "NODE", "NODES", "NOTE", "NOTED", "NOTES",
        "TONE", "TONED", "TONES", "DOTS", "DOT", "DOTE", "DOTES",
        "DONE", "DOSE", "DOES", "ONES", "ONE", "TEN", "TENS", "NET", "NETS",
        "SET", "SOT", "SON", "TON", "TONS", "NOSE", "NOSED", "ODE", "ODES",
        "SEND", "DENT", "DENTS", "DEN", "DENS", "END", "ENDS", "NEST",
        "SENT", "TENDS", "TEND", "ONSET", "STEN", "NODS", "NOD", "DOS",
        "EON", "EONS", "TOED", "TOE", "TOES", "DOSE", "SNOT", "TODS",
        // a few common extras for bonus-word play
        "CAT", "DOG", "SUN", "MOON", "ZEN", "DOOM",
    ]

    public static var dictionary: InMemoryDictionary {
        InMemoryDictionary(words: list)
    }
}
