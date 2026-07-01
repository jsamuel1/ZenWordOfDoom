import Foundation

/// Simple trial-division primality; adequate for the level counts this game
/// ever reaches (realistically tens to low hundreds of levels) — intentionally
/// not further optimized.
enum Primes {
    /// True if `n` is prime. 0, 1, and negatives are not prime.
    static func isPrime(_ n: Int) -> Bool {
        guard n >= 2 else { return false }
        if n < 4 { return true } // 2, 3
        if n.isMultiple(of: 2) { return false }
        var i = 3
        while i * i <= n {
            if n.isMultiple(of: i) { return false }
            i += 2
        }
        return true
    }

    /// The prime-counting function π(n): the number of primes p with 2 <= p <= n.
    static func count(upTo n: Int) -> Int {
        guard n >= 2 else { return 0 }
        return (2...n).lazy.filter(isPrime).count
    }
}
