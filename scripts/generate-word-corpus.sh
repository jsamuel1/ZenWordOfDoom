#!/bin/sh
# Regenerates words.txt (general corpus) and common-words.txt (familiar-word
# bias list) from the ESDB (formerly SCOWL) word database.
#
# Requires the ESDB toolchain already cloned and built (`make` run once) at
# the location given by $ESDB_DIR (defaults to ~/src/esdb-wordlist). ESDB
# itself is external to this repo -- only its filtered text output gets
# committed here. See docs/superpowers/specs/2026-07-03-scowl-esdb-word-corpus-design.md.
set -eu

ESDB_DIR="${ESDB_DIR:-$HOME/src/esdb-wordlist}"
if [ ! -f "$ESDB_DIR/scowl.db" ]; then
  echo "error: no scowl.db at $ESDB_DIR -- clone https://github.com/en-wl/wordlist and run 'make' there first" >&2
  exit 1
fi

cd "$(dirname "$0")/.."
RESOURCES="Sources/LevelGen/Resources"

extract() {
  # $1 = ESDB size, $2 = output file
  ( cd "$ESDB_DIR" && ./scowl --db scowl.db word-list "$1" A 1 ) \
    | tr 'a-z' 'A-Z' \
    | awk 'length($0) >= 3 && length($0) <= 9' \
    | sort -u > "$RESOURCES/$2"
}

extract 60 words.txt
extract 35 common-words.txt

echo "words.txt: $(wc -l < "$RESOURCES/words.txt" | tr -d ' ') words"
echo "common-words.txt: $(wc -l < "$RESOURCES/common-words.txt" | tr -d ' ') words"
