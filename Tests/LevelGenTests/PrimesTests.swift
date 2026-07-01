import XCTest
@testable import LevelGen

final class PrimesTests: XCTestCase {
    func test_isPrimeKnownValues() {
        let primes: Set<Int> = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31]
        for n in 2...31 {
            XCTAssertEqual(Primes.isPrime(n), primes.contains(n), "n=\(n)")
        }
        XCTAssertFalse(Primes.isPrime(1))
        XCTAssertFalse(Primes.isPrime(0))
        XCTAssertFalse(Primes.isPrime(-5))
    }

    func test_countUpToMatchesKnownPrimeCountingFunction() {
        XCTAssertEqual(Primes.count(upTo: 0), 0)
        XCTAssertEqual(Primes.count(upTo: 1), 0)
        XCTAssertEqual(Primes.count(upTo: 2), 1)
        XCTAssertEqual(Primes.count(upTo: 10), 4)
        XCTAssertEqual(Primes.count(upTo: 100), 25) // well-known π(100) = 25
    }
}
