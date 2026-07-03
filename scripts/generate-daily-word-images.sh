#!/bin/sh
# Generates the 24 Word-of-the-Day illustration slugs via the `agy`
# (Antigravity) CLI and installs each into Assets.xcassets, following the
# existing bundled-visuals convention (scene-<slug>.imageset/<slug>.jpg +
# Contents.json). Idempotent: re-running skips any slug that already has a
# bundled image, so a throttled run can simply be resumed later. Paced with
# a delay between calls since `agy` has usage limits.
set -eu

cd "$(dirname "$0")/.."
ASSETS_DIR="App/ZenWordOfDoom/Assets.xcassets"
DELAY_SECONDS=15
MAX_RETRIES=3

# slug|theme|prompt — one line per Word-of-the-Day illustration slug (Task 5's
# VisualPrompts entries, duplicated here as plain data since this script has
# no Swift runtime to read VisualPrompts.swift from).
SLUGS='
dawn-glow|zen|a warm golden sunrise over still hills, the sun'"'"'s disc faintly cracked with a hairline dark fissure, soft light, calm illustration
moonlit-hush|zen|a pale full moon over quiet rooftops, one bare skeletal branch in silhouette, soft blue light, calm illustration
still-water|zen|a calm mountain lake at dawn reflecting distant peaks, one faint wisp of dark smoke rising from a far peak, soft mist, serene illustration
quiet-garden|zen|a blooming garden of pale flowers in gentle morning light, one small blackened wilted bloom among them, calm illustration
lantern-calm|zen|a quiet mountain path lit by paper lanterns at dusk, one lantern flickering with a faint eerie green light, peaceful illustration
gentle-breath|zen|a figure meditating cross-legged under a soft glowing sky, a faint shadowy silhouette looming just behind, calm watercolor illustration
drifting-ease|zen|a single leaf with one scorched edge drifting slowly down a gentle stream, soft pastel illustration
warm-heart|zen|sunlight filtering through orchard branches onto a quiet path, one gnarled branch casting a claw-like shadow, warm calm illustration
nurtured-soul|zen|a quiet tide pool with a single seashell at dawn, a faint skull-like pattern in its swirl, soft pastel illustration
calm-balance|zen|a smooth stack of balanced stones on a still shoreline, the top stone faintly cracked, soft light, calm illustration
soft-whisper|zen|wind gently stirring tall grass under a twilight sky, one bare dead tree in silhouette on the horizon, soft illustration
graceful-harmony|zen|a slow waterfall over mossy stones in soft dappled light, a faint dark shadow pooling beneath, serene illustration
ashen-ruin|doom|crumbling stone ruins under an ash-grey sky, one delicate pale flower growing through the rubble, faint eerie glow, ominous stylized illustration
black-crypt|doom|a collapsing underground crypt lit by a single dim torch, a small smooth stone stack balanced quietly in one corner, ominous stylized illustration
cursed-hollow|doom|a twisted dead forest hollow under a bruised sky, a single lotus blossom glowing softly at the base of a dead tree, eerie stylized illustration
gravebound|doom|an overgrown forgotten graveyard gate at dusk, a small patch of raked zen sand and stones just inside the gate, cold light, ominous stylized illustration
festering-dark|doom|a decaying stone archway dripping with moss, one warm ray of golden light breaking through, sickly green glow, stylized illustration
shrieking-night|doom|a jagged mountain pass under a blood-red moon, a small still koi pond glimpsed calmly in the valley below, ominous stylized illustration
monstrous-thing|doom|a hulking shadowed silhouette looming behind fog, one paper lantern glowing gently and undisturbed nearby, deep violet glow, stylized illustration
forsaken-tomb|doom|an abandoned stone tomb sealed shut with old chains, a single bamboo shoot growing peacefully beside it, cold blue glow, stylized illustration
venomous-rite|doom|a ring of dark candles around a cracked stone altar, the crack forming a gentle raked-sand spiral, eerie glow, stylized illustration
spectral-dread|doom|a pale spectral shape drifting through a ruined hall, a small still reflecting pool of water on the floor below, cold light, stylized illustration
ravaged-earth|doom|a cracked and scorched battlefield under a smoky sky, one small green shoot pushing up through a crack, ominous stylized illustration
malevolent-omen|doom|a single glowing red eye watching from deep shadow, a faint lotus flower silhouette resting calmly nearby, stylized, ominous illustration
'

echo "$SLUGS" | while IFS='|' read -r slug theme prompt; do
  [ -z "$slug" ] && continue
  imageset_dir="$ASSETS_DIR/scene-$slug.imageset"
  image_path="$imageset_dir/$slug.png"

  if [ -s "$image_path" ] && [ -f "$imageset_dir/Contents.json" ]; then
    echo "skip $slug (already generated)"
    continue
  fi

  mkdir -p "$imageset_dir"
  attempt=1
  while [ "$attempt" -le "$MAX_RETRIES" ]; do
    echo "generating $slug (attempt $attempt/$MAX_RETRIES)..."
    if agy -p "Generate an illustration image for this description and save it as a PNG file to $PWD/$image_path: $prompt" --dangerously-skip-permissions < /dev/null; then
      if [ -s "$image_path" ]; then
        break
      fi
    fi
    echo "  retry after throttle/failure..."
    attempt=$((attempt + 1))
    sleep "$DELAY_SECONDS"
  done

  if [ ! -s "$image_path" ]; then
    echo "FAILED to generate $slug after $MAX_RETRIES attempts — re-run this script later to retry" >&2
    exit 1
  fi

  cat > "$imageset_dir/Contents.json" << EOF
{
  "images" : [
    {
      "filename" : "$slug.png",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

  echo "done $slug"
  sleep "$DELAY_SECONDS"
done

echo "All 24 Word-of-the-Day images generated."
