import XCTest
@testable import GameCore

final class FNV1aTests: XCTestCase {
    /// Reference FNV-1a (project's legacy basis), transcribed independently,
    /// pinning the algorithm.
    private func reference(_ text: String) -> UInt64 {
        var h: UInt64 = 1_469_598_103_934_665_603
        for b in text.utf8 { h = (h ^ UInt64(b)) &* 1_099_511_628_211 }
        return h
    }

    func testKnownVectors() {
        // Empty input returns the legacy offset basis unchanged.
        XCTAssertEqual(FNV1a.hash(""), 1_469_598_103_934_665_603)
        for s in ["a", "zen-easy-0", "daily-2026-07-02", "doommaster41"] {
            XCTAssertEqual(FNV1a.hash(s), reference(s), s)
        }
    }

    func testStableAcrossCalls() {
        XCTAssertEqual(FNV1a.hash("stability"), FNV1a.hash("stability"))
    }
}
