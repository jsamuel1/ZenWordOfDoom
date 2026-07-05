#!/bin/sh
# Generates the 6 picture-frame chrome textures (3 shapes x 2 themes) via the
# `agy` (Antigravity) CLI and installs each into Assets.xcassets/Frames/,
# following the existing bundled-visuals convention
# (frame-<theme>-<shape>.imageset/frame-<theme>-<shape>.png + Contents.json).
# Idempotent: re-running skips any texture that already has a bundled image
# (delete the .imageset dir first to force regeneration). Paced with a delay
# between calls since `agy` has usage limits.
#
# Texture design (see
# docs/superpowers/specs/2026-07-05-parchment-frame-v2-picture-frame-design.md
# section 4): each PNG is a THIN RING with a FULLY TRANSPARENT CENTER — the
# ring is the only opaque art; the center is left empty so the code-drawn mat
# fill (ParchmentChrome.swift / AccessibilityPalette's mat/ink constants)
# shows through untouched. This is a deliberate split from v1's textures,
# which tried to be both the border art and the full background fill via
# capInsets stretching — that's exactly what caused v1's oversizing/scrim
# bugs. Do not regenerate these as full-fill textures.
set -eu

cd "$(dirname "$0")/.."
ASSETS_DIR="App/ZenWordOfDoom/Assets.xcassets/Frames"
DELAY_SECONDS=15
MAX_RETRIES=3

# name|size|prompt — one line per texture.
TEXTURES='
frame-zen-button|900x300|A thin decorative rectangular picture-frame border made of smooth, rounded pale river stones and pebbles neatly arranged, in the style of a tranquil zen rock garden, pale grey and warm tan tones, only a thin border ring of stones around the outer edge (roughly the outer 15-20 percent of the image), the entire large center area completely empty and fully transparent with no fill at all, isolated on a transparent background, no text, alpha transparency in both the large empty center and outside the outer silhouette, calm minimalist illustration
frame-zen-icon|320x320|A thin decorative square picture-frame border made of smooth, rounded pale river stones and pebbles neatly arranged, in the style of a tranquil zen rock garden, pale grey and warm tan tones, only a thin border ring of stones around the outer edge (roughly the outer 15-20 percent of the image), the entire large center area completely empty and fully transparent with no fill at all, isolated on a transparent background, no text, alpha transparency in both the large empty center and outside the outer silhouette, calm minimalist illustration
frame-zen-strip|900x160|A thin decorative rectangular picture-frame border made of smooth, rounded pale river stones and pebbles neatly arranged, in the style of a tranquil zen rock garden, pale grey and warm tan tones, only a thin border ring of stones around the outer edge (roughly the outer 20-25 percent of the image, this is a short banner shape), the entire large center area completely empty and fully transparent with no fill at all, isolated on a transparent background, no text, alpha transparency in both the large empty center and outside the outer silhouette, calm minimalist illustration
frame-doom-button|900x300|A thin decorative rectangular picture-frame border made of rough, crumbling volcanic basalt rock, COOL GREY stone tones (explicitly not brown, not tan, not charred-wood colored — grey basalt like cooled lava rock) with faint, subtle, low-intensity glowing orange lava-crack veins running through the grey stone (thin and understated, not bright or bold), only a thin border ring of rock around the outer edge (roughly the outer 15-20 percent of the image), the entire large center area completely empty and fully transparent with no fill at all, isolated on a transparent background, no text, alpha transparency in both the large empty center and outside the outer silhouette, subtle ominous stylized illustration
frame-doom-icon|320x320|A thin decorative square picture-frame border made of rough, crumbling volcanic basalt rock, COOL GREY stone tones (explicitly not brown, not tan, not charred-wood colored — grey basalt like cooled lava rock) with faint, subtle, low-intensity glowing orange lava-crack veins running through the grey stone (thin and understated, not bright or bold), only a thin border ring of rock around the outer edge (roughly the outer 15-20 percent of the image), the entire large center area completely empty and fully transparent with no fill at all, isolated on a transparent background, no text, alpha transparency in both the large empty center and outside the outer silhouette, subtle ominous stylized illustration
frame-doom-strip|900x160|A thin decorative rectangular picture-frame border made of rough, crumbling volcanic basalt rock, COOL GREY stone tones (explicitly not brown, not tan, not charred-wood colored — grey basalt like cooled lava rock) with faint, subtle, low-intensity glowing orange lava-crack veins running through the grey stone (thin and understated, not bright or bold), only a thin border ring of rock around the outer edge (roughly the outer 20-25 percent of the image, this is a short banner shape), the entire large center area completely empty and fully transparent with no fill at all, isolated on a transparent background, no text, alpha transparency in both the large empty center and outside the outer silhouette, subtle ominous stylized illustration
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

  # Marked as @3x: these PNGs are generated at print-quality canvas sizes
  # (e.g. 900x300) that are much larger than the ~50pt-tall button they
  # actually render at. Without a scale marking, capInsets (specified in
  # points against the image's own logical size) would need to describe a
  # 900x300-point image — forcing capInset sums far bigger than any real
  # button's height and reintroducing v1's oversizing bug. @3x makes the
  # logical size 300x100pt, so capInsets in ParchmentShape.swift are the
  # measured pixel thickness divided by 3.
  cat > "$imageset_dir/Contents.json" << EOF
{
  "images" : [
    {
      "filename" : "$name.png",
      "idiom" : "universal",
      "scale" : "3x"
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

echo "All 6 picture-frame textures generated."
