import XCTest
import LevelGen
@testable import ZenWordOfDoom

/// Asset selection is the seam between the generator's slug pools and the
/// bundled art. A mismatch is silent — an unknown slug falls through to the
/// procedural renderer — so these tests guard both directions: the lookup
/// resolves known slugs and rejects unknown ones, and every slug the generator
/// can emit actually has bundled art.
final class BundledVisualsTests: XCTestCase {

    func testAssetNameForBundledSlugs() {
        XCTAssertEqual(BundledVisuals.assetName(kind: .scene, id: "still-pond"),
                       "scene-still-pond")
        XCTAssertEqual(BundledVisuals.assetName(kind: .creature, id: "koi-spirit"),
                       "creature-koi-spirit")
        XCTAssertEqual(BundledVisuals.assetName(kind: .scene, id: "ember-catacomb"),
                       "scene-ember-catacomb")
        XCTAssertEqual(BundledVisuals.assetName(kind: .creature, id: "ash-maw"),
                       "creature-ash-maw")
    }

    func testAssetNameIsNilForUnknownSlug() {
        XCTAssertNil(BundledVisuals.assetName(kind: .scene, id: "no-such-scene"))
        XCTAssertNil(BundledVisuals.assetName(kind: .creature, id: "no-such-creature"))
        // Kind is part of the name: a real creature slug under `.scene` is unknown.
        XCTAssertNil(BundledVisuals.assetName(kind: .scene, id: "koi-spirit"))
        XCTAssertNil(BundledVisuals.assetName(kind: .creature, id: "still-pond"))
    }

    /// Invariant: every slug the generator can pick has bundled art. If the
    /// curated pools ever gain a slug without a matching asset, the generator
    /// would silently drop to the procedural fallback — this test fails first.
    func testEveryZenDoomSlugHasBundledAsset() {
        let pools = ThemePools.zenDoom
        for theme in Theme.allCases {
            for slug in pools.scenes[theme] ?? [] {
                XCTAssertTrue(BundledVisuals.knownAssets.contains("scene-\(slug)"),
                              "scene slug '\(slug)' (\(theme)) has no bundled asset")
                XCTAssertEqual(BundledVisuals.assetName(kind: .scene, id: slug),
                               "scene-\(slug)")
            }
            for slug in pools.creatures[theme] ?? [] {
                XCTAssertTrue(BundledVisuals.knownAssets.contains("creature-\(slug)"),
                              "creature slug '\(slug)' (\(theme)) has no bundled asset")
                XCTAssertEqual(BundledVisuals.assetName(kind: .creature, id: slug),
                               "creature-\(slug)")
            }
        }
    }

    /// Same invariant as `testEveryZenDoomSlugHasBundledAsset`, but for the
    /// Word-of-the-Day illustration slugs (a separate pool from the regular
    /// scene/creature pools, but the same `.scene` kind and naming scheme).
    func testEveryWordOfTheDaySlugHasBundledAsset() {
        for theme in Theme.allCases {
            for slug in WordOfTheDayImages.slugs(for: theme) {
                XCTAssertTrue(BundledVisuals.knownAssets.contains("scene-\(slug)"),
                              "word-of-the-day slug '\(slug)' (\(theme)) has no bundled asset")
                XCTAssertEqual(BundledVisuals.assetName(kind: .scene, id: slug), "scene-\(slug)")
            }
        }
    }
}
