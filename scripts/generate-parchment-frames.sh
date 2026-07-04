#!/bin/sh
# Generates the 6 parchment/oriental-frame chrome textures (3 shapes x 2
# themes) via the `agy` (Antigravity) CLI and installs each into
# Assets.xcassets/Frames/, following the existing bundled-visuals convention
# (frame-<theme>-<shape>.imageset/frame-<theme>-<shape>.png + Contents.json).
# Idempotent: re-running skips any texture that already has a bundled image.
# Paced with a delay between calls since `agy` has usage limits.
#
# Texture design (see docs/superpowers/specs/2026-07-04-parchment-frame-chrome-design.md
# section 4-5): each PNG has a transparent margin outside its torn silhouette,
# a richly-detailed torn-edge/corner-ornament border, and a near-solid,
# low-variance center panel toned to blend with the matching code-drawn scrim
# (ParchmentChrome.swift / AccessibilityPalette.parchmentScrim(for:)) rather
# than fighting it.
set -eu

cd "$(dirname "$0")/.."
ASSETS_DIR="App/ZenWordOfDoom/Assets.xcassets/Frames"
DELAY_SECONDS=15
MAX_RETRIES=3

# name|size|prompt — one line per texture.
TEXTURES='
frame-zen-button|900x300|A wide rectangular aged parchment texture with softly torn deckled edges and a delicate oriental ink-line corner ornament in each corner, warm tea-stained cream color, the center two-thirds a smooth near-solid muted warm cream tone designed to blend under a matching semi-transparent cream overlay, isolated on a transparent background, no text, alpha transparency outside the torn paper silhouette, restrained and calm illustration style
frame-zen-icon|320x320|A small square aged parchment medallion with torn deckled edges all around and a delicate oriental ink-line ornament framing the border, warm tea-stained cream color, the center a smooth near-solid muted warm cream tone designed to blend under a matching semi-transparent cream overlay, isolated on a transparent background, no text, alpha transparency outside the torn paper silhouette, restrained and calm illustration style
frame-zen-strip|900x160|A thin horizontal banner strip of aged parchment with torn deckled edges on the short ends and a delicate oriental ink-line ornament at each end, warm tea-stained cream color, the center a smooth near-solid muted warm cream tone designed to blend under a matching semi-transparent cream overlay, isolated on a transparent background, no text, alpha transparency outside the torn paper silhouette, restrained and calm illustration style
frame-doom-button|900x300|A wide rectangular scorched and charred aged parchment texture with jagged burnt torn edges and a heavy blackened oriental corner ornament in each corner, dark charred brown color, the center two-thirds a smooth near-solid muted charred-brown tone designed to blend under a matching semi-transparent dark overlay, isolated on a transparent background, no text, alpha transparency outside the torn paper silhouette, ominous stylized illustration
frame-doom-icon|320x320|A small square scorched and charred aged parchment medallion with jagged burnt torn edges all around and a heavy blackened oriental ornament framing the border, dark charred brown color, the center a smooth near-solid muted charred-brown tone designed to blend under a matching semi-transparent dark overlay, isolated on a transparent background, no text, alpha transparency outside the torn paper silhouette, ominous stylized illustration
frame-doom-strip|900x160|A thin horizontal banner strip of scorched and charred aged parchment with jagged burnt torn edges on the short ends and a heavy blackened oriental ornament at each end, dark charred brown color, the center a smooth near-solid muted charred-brown tone designed to blend under a matching semi-transparent dark overlay, isolated on a transparent background, no text, alpha transparency outside the torn paper silhouette, ominous stylized illustration
'

echo "$TEXTURES" | while IFS='|' read -r name size prompt; do
  [ -z "$name" ] && continue
  imageset_dir="$ASSETS_DIR/$name.imageset"
  image_path="$imageset_dir/$name.png"

  if [ -s "$image_path" ] && [ -f "$imageset_dir/Contents.json" ]; then
    echo "skip $name (already generated)"
    continue
  fi

  mkdir -p "$imageset_dir"
  attempt=1
  while [ "$attempt" -le "$MAX_RETRIES" ]; do
    echo "generating $name ($size, attempt $attempt/$MAX_RETRIES)..."
    if agy -p "Generate a $size pixel PNG image with alpha transparency for this description and save it to $PWD/$image_path: $prompt" --dangerously-skip-permissions < /dev/null; then
      if [ -s "$image_path" ]; then
        break
      fi
    fi
    echo "  retry after throttle/failure..."
    attempt=$((attempt + 1))
    sleep "$DELAY_SECONDS"
  done

  if [ ! -s "$image_path" ]; then
    echo "FAILED to generate $name after $MAX_RETRIES attempts — re-run this script later to retry" >&2
    exit 1
  fi

  cat > "$imageset_dir/Contents.json" << EOF
{
  "images" : [
    {
      "filename" : "$name.png",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

  echo "done $name"
  sleep "$DELAY_SECONDS"
done

echo "All 6 parchment-frame textures generated."
