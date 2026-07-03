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
  #
  # Order matters: normalize diacritics to their plain-ASCII equivalent
  # BEFORE uppercasing -- macOS's iconv doesn't support //TRANSLIT
  # transliteration reliably, so this uses Python's Unicode NFKD
  # decomposition + ASCII-encode-and-drop instead (e.g. CAFÉ -> CAFE).
  # Without this step, ESDB's few accented entries (loanwords like café,
  # résumé, café, olé) survive as non-ASCII and silently shadow/replace the
  # plain-ASCII spelling a player's letter tiles would actually produce.
  #
  # The final `grep -E '^[A-Z]{3,9}$'` (replacing a plain length check)
  # additionally rejects anything that isn't purely A-Z after the above --
  # this is what drops ESDB's ~11k/~3k possessive entries (ABE'S, ABBOTT'S)
  # per size tier, since an apostrophe never matches `[A-Z]`.
  ( cd "$ESDB_DIR" && ./scowl --db scowl.db word-list "$1" A 1 ) \
    | python3 -c '
import sys, unicodedata
for line in sys.stdin:
    print(unicodedata.normalize("NFKD", line.rstrip(chr(10))).encode("ascii", "ignore").decode())
' \
    | tr 'a-z' 'A-Z' \
    | grep -E '^[A-Z]{3,9}$' \
    | sort -u > "$RESOURCES/$2"
}

extract 60 words.txt
extract 35 common-words.txt

echo "words.txt: $(wc -l < "$RESOURCES/words.txt" | tr -d ' ') words"
echo "common-words.txt: $(wc -l < "$RESOURCES/common-words.txt" | tr -d ' ') words"
