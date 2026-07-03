import GameCore

/// IP-free, guardrail-safe image prompts for the curated scene/creature slugs.
/// Bump `promptVersion` whenever prompt text changes (invalidates the cache).
public enum VisualPrompts {
    public static let promptVersion = 1

    public static func prompt(forSceneID id: String, theme: Theme) -> String {
        scenePrompts[id] ?? genericScene(theme)
    }
    public static func prompt(forCreatureID id: String, theme: Theme) -> String {
        creaturePrompts[id] ?? genericCreature(theme)
    }

    private static func genericScene(_ t: Theme) -> String {
        t == .zen
        ? "a serene minimalist nature scene, soft pastel light, calm illustration"
        : "an ancient ruined place at night, faint eerie glow, ominous stylized illustration"
    }
    private static func genericCreature(_ t: Theme) -> String {
        t == .zen
        ? "a gentle glowing spirit guardian, soft watercolor, calm"
        : "a mysterious shadowy creature with glowing eyes, deep teal and violet, stylized, ominous but not gory"
    }

    private static let scenePrompts: [String: String] = [
        "still-pond": "a calm koi pond at dawn, soft mist, pastel illustration",
        "moss-garden": "a quiet moss garden with smooth stones, gentle green light, calm illustration",
        "bamboo-grove": "a tranquil bamboo grove, soft sunbeams, serene illustration",
        "misty-peak": "a distant mountain peak above soft clouds, pale dawn, calm illustration",
        "lantern-path": "a winding stone path lit by paper lanterns at dusk, peaceful illustration",
        "sand-ripples": "a raked zen sand garden in concentric ripples, soft shadows, calm illustration",
        "willow-bank": "a willow tree over a still river bank, gentle breeze, serene illustration",
        "sunken-crypt": "an ancient overgrown stone crypt at night, faint green glow, ominous stylized illustration",
        "black-abyss": "a yawning dark chasm with faint glowing motes, deep blue-black, ominous stylized illustration",
        "thorn-hollow": "a twisted thorn thicket under a blood-orange moon, eerie, stylized illustration",
        "ruined-shrine": "a crumbling forgotten shrine wreathed in fog, cold light, ominous stylized illustration",
        "ashen-moor": "a bleak ash-grey moor under a bruised sky, lonely, ominous stylized illustration",
        "drowned-temple": "a half-submerged stone temple in dark water, teal gloom, ominous stylized illustration",
        "ember-catacomb": "a shadowy catacomb lit by dim embers, deep red glow, ominous stylized illustration",
        // Word-of-the-Day slugs (Zen)
        "dawn-glow": "a warm golden sunrise breaking over still hills, soft light, calm illustration",
        "moonlit-hush": "a pale full moon over quiet rooftops, soft blue light, calm illustration",
        "still-water": "a calm mountain lake at dawn reflecting distant peaks, soft mist, serene illustration",
        "quiet-garden": "a blooming garden of pale flowers in gentle morning light, calm illustration",
        "lantern-calm": "a quiet mountain path lit by paper lanterns at dusk, peaceful illustration",
        "gentle-breath": "a figure meditating cross-legged under a soft glowing sky, calm watercolor illustration",
        "drifting-ease": "a single leaf drifting slowly down a gentle stream, soft pastel illustration",
        "warm-heart": "sunlight filtering through orchard branches onto a quiet path, warm calm illustration",
        "nurtured-soul": "a quiet tide pool with a single seashell at dawn, soft pastel illustration",
        "calm-balance": "a smooth stack of balanced stones on a still shoreline, soft light, calm illustration",
        "soft-whisper": "wind gently stirring tall grass under a twilight sky, soft illustration",
        "graceful-harmony": "a slow waterfall over mossy stones in soft dappled light, serene illustration",
        // Word-of-the-Day slugs (Doom)
        "ashen-ruin": "crumbling stone ruins under an ash-grey sky, faint eerie glow, ominous stylized illustration",
        "black-crypt": "a collapsing underground crypt lit by a single dim torch, ominous stylized illustration",
        "cursed-hollow": "a twisted dead forest hollow under a bruised sky, eerie stylized illustration",
        "gravebound": "an overgrown forgotten graveyard gate at dusk, cold light, ominous stylized illustration",
        "festering-dark": "a decaying stone archway dripping with moss, sickly green glow, stylized illustration",
        "shrieking-night": "a jagged mountain pass under a blood-red moon, ominous stylized illustration",
        "monstrous-thing": "a hulking shadowed silhouette looming behind fog, deep violet glow, stylized illustration",
        "forsaken-tomb": "an abandoned stone tomb sealed shut with old chains, cold blue glow, stylized illustration",
        "venomous-rite": "a ring of dark candles around a cracked stone altar, eerie glow, stylized illustration",
        "spectral-dread": "a pale spectral shape drifting through a ruined hall, cold light, stylized illustration",
        "ravaged-earth": "a cracked and scorched battlefield under a smoky sky, ominous stylized illustration",
        "malevolent-omen": "a single glowing red eye watching from deep shadow, stylized, ominous illustration",
    ]
    private static let creaturePrompts: [String: String] = [
        "koi-spirit": "a serene glowing koi spirit, soft watercolor, calm",
        "stone-guardian": "a mossy stone guardian statue with kind eyes, soft light, calm illustration",
        "crane-shade": "a graceful pale crane silhouette in mist, serene illustration",
        "lotus-wisp": "a glowing lotus-shaped wisp of light, soft pastels, calm",
        "moss-golem": "a gentle round golem of moss and stone, soft green, calm illustration",
        "paper-fox": "a delicate origami fox glowing softly, calm pastel illustration",
        "deep-tentacle": "a coiling deep-sea tentacle creature, teal and violet, eerie bioluminescent glow, stylized",
        "gloom-eye": "a single large floating eye sigil ringed with runes, sickly green glow, stylized, ominous",
        "bone-wraith": "a tattered hooded wraith of pale bone and shadow, cold blue glow, stylized, ominous not gory",
        "mask-fiend": "an ancient cracked ritual mask with an eerie green glow, stylized, ominous",
        "thorn-revenant": "a figure woven from black thorns and fog, glowing eyes, stylized, ominous not gory",
        "ash-maw": "a shadowy maw of drifting ash and embers, deep red glow, abstract, stylized, ominous",
    ]
}
