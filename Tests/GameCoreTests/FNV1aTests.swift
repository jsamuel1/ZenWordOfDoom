import XCTest
@testable import GameCore

final class FNV1aTests: XCTestCase {
    /// Reference FNV-1a, transcribed independently, pinning the algorithm.
    private func reference(_ text: String) -> UInt64 {
        var h: UInt64 = 14_695_981_039_346_656_037
        for b in text.utf8 { h = (h ^ UInt64(b)) &* 1_099_511_628_211 }
        return h
    }

    func testKnownVectors() {
        XCTAssertEqual(FNV1a.hash(""), 0xcbf29ce484222325)
        for s in ["a", "zen-easy-0", "daily-2026-07-02", "doommaster41"] {
            XCTAssertEqual(FNV1a.hash(s), reference(s), s)
        }
    }

    func testStableAcrossCalls() {
        XCTAssertEqual(FNV1a.hash("stability"), FNV1a.hash("stability"))
    }
}
