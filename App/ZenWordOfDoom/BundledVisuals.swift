import LevelGen

/// Pre-rendered fallback art bundled in `Assets.xcassets`, used when on-device
/// generation is unavailable (no Apple Intelligence, simulator, content
/// refusal, timeout). Generated once offline from the same `VisualPrompts`
/// used for live generation, so the aesthetic matches. Asset catalog names are
/// `"<kind>-<slug>"`; only slugs actually bundled are listed here, so an
/// unknown/future slug cleanly falls through to the procedural fallback.
enum BundledVisuals {
    static func assetName(for request: VisualRequest) -> String? {
        assetName(kind: request.kind, id: request.id)
    }

    /// Bundled asset name for a `kind`/`id` slug, or nil if none is bundled.
    /// Theme-independent (asset names are `"<kind>-<slug>"`).
    static func assetName(kind: VisualKind, id: String) -> String? {
        let name = "\(kind.rawValue)-\(id)"
        return knownAssets.contains(name) ? name : nil
    }

    /// The exact set of bundled asset-catalog names. Internal (not private) so
    /// the app test target can assert the generator's slug pools are fully
    /// covered by bundled art.
    static let knownAssets: Set<String> = [
        // Zen scenes
        "scene-still-pond", "scene-moss-garden", "scene-bamboo-grove",
        "scene-misty-peak", "scene-lantern-path", "scene-sand-ripples",
        "scene-willow-bank",
        // Doom scenes
        "scene-sunken-crypt", "scene-black-abyss", "scene-thorn-hollow",
        "scene-ruined-shrine", "scene-ashen-moor", "scene-drowned-temple",
        "scene-ember-catacomb",
        // Zen creatures
        "creature-koi-spirit", "creature-stone-guardian", "creature-crane-shade",
        "creature-lotus-wisp", "creature-moss-golem", "creature-paper-fox",
        // Doom creatures
        "creature-deep-tentacle", "creature-gloom-eye", "creature-bone-wraith",
        "creature-mask-fiend", "creature-thorn-revenant", "creature-ash-maw",
        // Word-of-the-Day slugs (Zen)
        "scene-dawn-glow", "scene-moonlit-hush", "scene-still-water", "scene-quiet-garden",
        "scene-lantern-calm", "scene-gentle-breath", "scene-drifting-ease", "scene-warm-heart",
        "scene-nurtured-soul", "scene-calm-balance", "scene-soft-whisper", "scene-graceful-harmony",
        // Word-of-the-Day slugs (Doom)
        "scene-ashen-ruin", "scene-black-crypt", "scene-cursed-hollow", "scene-gravebound",
        "scene-festering-dark", "scene-shrieking-night", "scene-monstrous-thing", "scene-forsaken-tomb",
        "scene-venomous-rite", "scene-spectral-dread", "scene-ravaged-earth", "scene-malevolent-omen",
    ]
}
