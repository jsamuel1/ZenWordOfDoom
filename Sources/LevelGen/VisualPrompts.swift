import GameCore

/// IP-free, guardrail-safe image prompts for the curated scene/creature slugs.
/// Bump `promptVersion` whenever prompt text changes (invalidates the cache).
public enum VisualPrompts {
    public static let promptVersion = 2

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
        // Word-of-the-Day slugs (Zen, with a faint touch of Doom)
        "dawn-glow": "a warm golden sunrise over still hills, the sun's disc faintly cracked with a hairline dark fissure, soft light, calm illustration",
        "moonlit-hush": "a pale full moon over quiet rooftops, one bare skeletal branch in silhouette, soft blue light, calm illustration",
        "still-water": "a calm mountain lake at dawn reflecting distant peaks, one faint wisp of dark smoke rising from a far peak, soft mist, serene illustration",
        "quiet-garden": "a blooming garden of pale flowers in gentle morning light, one small blackened wilted bloom among them, calm illustration",
        "lantern-calm": "a quiet mountain path lit by paper lanterns at dusk, one lantern flickering with a faint eerie green light, peaceful illustration",
        "gentle-breath": "a figure meditating cross-legged under a soft glowing sky, a faint shadowy silhouette looming just behind, calm watercolor illustration",
        "drifting-ease": "a single leaf with one scorched edge drifting slowly down a gentle stream, soft pastel illustration",
        "warm-heart": "sunlight filtering through orchard branches onto a quiet path, one gnarled branch casting a claw-like shadow, warm calm illustration",
        "nurtured-soul": "a quiet tide pool with a single seashell at dawn, a faint skull-like pattern in its swirl, soft pastel illustration",
        "calm-balance": "a smooth stack of balanced stones on a still shoreline, the top stone faintly cracked, soft light, calm illustration",
        "soft-whisper": "wind gently stirring tall grass under a twilight sky, one bare dead tree in silhouette on the horizon, soft illustration",
        "graceful-harmony": "a slow waterfall over mossy stones in soft dappled light, a faint dark shadow pooling beneath, serene illustration",
        // Word-of-the-Day slugs (Doom, with a faint touch of Zen)
        "ashen-ruin": "crumbling stone ruins under an ash-grey sky, one delicate pale flower growing through the rubble, faint eerie glow, ominous stylized illustration",
        "black-crypt": "a collapsing underground crypt lit by a single dim torch, a small smooth stone stack balanced quietly in one corner, ominous stylized illustration",
        "cursed-hollow": "a twisted dead forest hollow under a bruised sky, a single lotus blossom glowing softly at the base of a dead tree, eerie stylized illustration",
        "gravebound": "an overgrown forgotten graveyard gate at dusk, a small patch of raked zen sand and stones just inside the gate, cold light, ominous stylized illustration",
        "festering-dark": "a decaying stone archway dripping with moss, one warm ray of golden light breaking through, sickly green glow, stylized illustration",
        "shrieking-night": "a jagged mountain pass under a blood-red moon, a small still koi pond glimpsed calmly in the valley below, ominous stylized illustration",
        "monstrous-thing": "a hulking shadowed silhouette looming behind fog, one paper lantern glowing gently and undisturbed nearby, deep violet glow, stylized illustration",
        "forsaken-tomb": "an abandoned stone tomb sealed shut with old chains, a single bamboo shoot growing peacefully beside it, cold blue glow, stylized illustration",
        "venomous-rite": "a ring of dark candles around a cracked stone altar, the crack forming a gentle raked-sand spiral, eerie glow, stylized illustration",
        "spectral-dread": "a pale spectral shape drifting through a ruined hall, a small still reflecting pool of water on the floor below, cold light, stylized illustration",
        "ravaged-earth": "a cracked and scorched battlefield under a smoky sky, one small green shoot pushing up through a crack, ominous stylized illustration",
        "malevolent-omen": "a single glowing red eye watching from deep shadow, a faint lotus flower silhouette resting calmly nearby, stylized, ominous illustration",
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
