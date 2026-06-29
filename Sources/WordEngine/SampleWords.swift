import Foundation
import GameCore

/// A tiny built-in word list so the app and tests run before a full,
/// license-cleared dictionary is bundled (see docs/SPEC.md §13).
///
/// Includes the original STONED words plus the full canonical word list
/// used to author levels. Entries are de-duplicated.
public enum SampleWords {
    /// The full canonical word list (verbatim) that level answers draw from.
    public static let canonical: [String] = [
        // STONED family
        "STONE", "STONED", "NODE", "NODES", "NOTE", "NOTES", "TONE", "TONES",
        "DOT", "DOTS", "DOTE", "DOSE", "DONE", "NOSE", "ODE", "ODES", "TEN",
        "TENS", "NET", "NETS", "SET", "SON", "TON", "TONS", "EON", "EONS",
        "TOE", "TOES", "SNOT", "ONSET",
        // CALM family
        "CALM", "CLAM", "LAMP", "LAMPS", "PALM", "PALMS", "MAPLE", "AMPLE",
        "PLEA", "PEAL", "PALE", "PALES", "LEAP", "LEAPS", "MEAL", "MEALS",
        "LAME", "LAMES", "SEAL", "MALE", "MALES",
        // GARDEN family
        "GARDEN", "GRADE", "GRADES", "RANGE", "RANGED", "DANGER", "GANDER",
        "ANGER", "RAGED", "GRAND", "READ", "DEAR", "DARE", "DARES", "RAGE",
        "RAGES", "GEAR", "GEARS", "NEAR", "DEAN", "DEANS",
        // LOTUS family
        "LOTUS", "LOUT", "LOUTS", "SOUL", "SLOT", "SLOTS", "LOST", "LOTS",
        "OUST", "TOIL", "SILO", "SOIL", "COIL", "COILS", "STOIC",
        // SHADOW family
        "SHADOW", "SHADE", "SHADES", "HEADS", "AHEAD", "HASTE", "HEATS",
        "HATE", "HATES", "HEAT", "EARTH", "HEART", "HEARTS",
        // EMBER family
        "EMBER", "EMBERS", "MERGE", "TIMBER", "LIMBER",
        // RIVER family
        "RIVER", "DRIVE", "DRIVER", "DIVER", "RIDE", "RIDES", "DIRE", "DIVE",
        "FIRED", "FRIED",
    ]

    /// Words preserved from the original STONED-only sample list. These extend
    /// the canonical list with a few inflections and bonus-word extras.
    private static let extras: [String] = [
        // additional STONED inflections kept for backward compatibility
        "NOTED", "TONED", "DOTES", "DOES", "ONES", "ONE", "SOT", "NOSED",
        "SEND", "DENT", "DENTS", "DEN", "DENS", "END", "ENDS", "NEST",
        "SENT", "TENDS", "TEND", "STEN", "NODS", "NOD", "DOS", "TOED",
        "TODS",
        // common extras for bonus-word play
        "CAT", "DOG", "SUN", "MOON", "ZEN", "DOOM",
    ]

    /// The complete de-duplicated word list (canonical + extras), order-stable.
    public static let list: [String] = {
        var seen = Set<String>()
        var result: [String] = []
        for word in canonical + extras {
            let upper = word.uppercased()
            if seen.insert(upper).inserted {
                result.append(upper)
            }
        }
        return result
    }()

    public static var dictionary: InMemoryDictionary {
        InMemoryDictionary(words: list)
    }
}
