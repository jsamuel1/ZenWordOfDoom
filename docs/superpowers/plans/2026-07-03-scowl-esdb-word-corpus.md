# SCOWL/ESDB Word Corpus Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `words.txt`, `common-words.txt`, and grow `seed-zen.txt`/`seed-doom.txt` with ESDB-derived content, via a new repeatable generation script, with proper attribution.

**Architecture:** A new shell script drives the already-built ESDB toolchain (`~/src/esdb-wordlist`, external to this repo) to extract and filter two corpus files. The theme lexicons are grown with a pre-validated (against the new corpus), hand-curated topical word list embedded directly in this plan. No Swift loading code changes anywhere — `GeneralWordList`, `CommonWords`, and `ThemeLexicon` already just read whatever uppercase, newline-separated content is in their resource files.

**Tech Stack:** Swift 5.9 (Swift Package Manager, `LevelGen` target), shell script driving the external ESDB Python/SQLite toolchain, XCTest.

## Global Constraints

- ESDB size **60**, American English (`A`), variant-level 1 for the general corpus (`words.txt`) — real count at 3-9 letters: **61,719 words**.
- ESDB size **35**, American English (`A`), variant-level 1 for `common-words.txt` — real count at 3-9 letters: **29,624 words**.
- Every word in every resource file is uppercase, 3-9 letters, one per line, sorted, deduplicated.
- The ESDB toolchain lives at `~/src/esdb-wordlist` (already cloned and built, `make` run successfully) — external to this repo, read from an environment variable so the script is portable, never vendored.
- Theme lexicon words (`seed-zen.txt`/`seed-doom.txt`) must each be present in the regenerated `words.txt` — same "every word is real and buildable" discipline the rest of the codebase already enforces.
- No two words appear in both `seed-zen.txt` and `seed-doom.txt` (existing invariant, confirmed true of the current shipped lists).
- ESDB's copyright notice must appear in this repo's supporting documentation (its license requirement for redistributing word lists derived from it).

---

### Task 1: Word corpus generation script + regenerate `words.txt` and `common-words.txt`

**Files:**
- Create: `scripts/generate-word-corpus.sh`
- Modify: `Sources/LevelGen/Resources/words.txt` (regenerated content)
- Modify: `Sources/LevelGen/Resources/common-words.txt` (regenerated content)

**Interfaces:**
- Produces: two regenerated resource files that `GeneralWordList`/`CommonWords` (existing, unchanged Swift types in `Sources/LevelGen/GeneralWordList.swift` and `Sources/LevelGen/CommonWords.swift`) load exactly as before — no code changes, no new interface.

- [ ] **Step 1: Write the generation script**

Create `scripts/generate-word-corpus.sh`:

```bash
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
```

Make it executable: `chmod +x scripts/generate-word-corpus.sh`

- [ ] **Step 2: Run it**

Run: `./scripts/generate-word-corpus.sh`

Expected output:
```
words.txt: 61719 words
common-words.txt: 29624 words
```

- [ ] **Step 3: Run the existing corpus tests to verify they still pass against the new content**

Run: `swift test --filter GeneralWordListTests`
Expected: PASS (all 4 tests — `test_loadsLargeCorpus` passes trivially at 61,719 > 50,000; `GARDEN`/`RANGE`/`MOONLIGHT` are all present in the new size-60 corpus, confirmed during research)

Run: `swift test --filter CommonWordsTests`
Expected: PASS (both tests — `test_loadsManyWords` passes trivially at 29,624 > 1,000; `LIST`/`STILL`/`STONE` are present and `LITS`/`TILS` are absent from the new size-35 corpus, confirmed during research)

- [ ] **Step 4: Commit**

```bash
git add scripts/generate-word-corpus.sh Sources/LevelGen/Resources/words.txt Sources/LevelGen/Resources/common-words.txt
git commit -m "feat(levelgen): regenerate word corpus from ESDB (formerly SCOWL)"
```

---

### Task 2: Grow the Zen theme lexicon

**Files:**
- Modify: `Sources/LevelGen/Resources/seed-zen.txt` (replace content)
- Modify: `Tests/LevelGenTests/ThemeLexiconTests.swift`

**Interfaces:**
- Consumes: `Sources/LevelGen/Resources/words.txt` (Task 1) — every word below was validated present in the regenerated corpus during this plan's research.
- Produces: `ThemeLexicon.words(for: .zen)` (existing, unchanged code in `Sources/LevelGen/ThemeLexicon.swift`) now returns 331 words instead of 85 — no interface change, just more content.

- [ ] **Step 1: Replace `seed-zen.txt`'s content**

Replace `Sources/LevelGen/Resources/seed-zen.txt` with exactly this content (331 words, one per line, alphabetically sorted — every word already confirmed present in the Task 1-regenerated `words.txt`):

```
AIRY
ALCOVE
ANCIENT
ARBOR
ASCEND
AURA
AWAKEN
AWARENESS
AZALEA
BABBLE
BALANCE
BAMBOO
BASIL
BEACH
BELL
BIRCH
BLESSING
BLISS
BLOOM
BLOSSOM
BLUEBELL
BOULDER
BOUNDLESS
BRANCH
BREATHE
BREEZE
BRIDGE
BRIGHT
BRILLIANT
BROOK
BUTTERCUP
BUTTERFLY
CADENCE
CALM
CANDLE
CANYON
CASCADE
CAVE
CEDAR
CENTER
CHAMOMILE
CHERISH
CHERRY
CHIME
CINNAMON
CLARITY
CLEAN
CLEAR
CLIFF
CLOUD
CLOVER
COMFORT
COMPLETE
CONSTANT
CONTENT
COSMOS
COTTON
COURTYARD
COZY
CRADLE
CRANE
CREAM
CREEK
CRICKET
CURRENT
DAFFODIL
DAISY
DANDELION
DAWN
DELICATE
DELIGHT
DEW
DIM
DIVINE
DOVE
DOWNY
DOZE
DRAGONFLY
DREAM
DRIFTING
DRIZZLE
DROWSY
DUSK
EASE
ECHO
EDDY
ELEGANT
ELEVATE
ELYSIUM
EMBRACE
EMPATHY
ENDURE
ENERGY
ENLIGHTEN
ESSENCE
ETERNITY
EXHALE
EXPANSE
FAINT
FEATHER
FEATHERY
FERN
FIELD
FINE
FIREFLY
FLOATING
FLOW
FLOWER
FLUFFY
FLYING
FOCUS
FOG
FOREST
FOUNTAIN
FOXGLOVE
FRAGILE
FREEDOM
FRESH
FULFILL
GARDEN
GARDENIA
GENTLE
GLEAM
GLIDING
GLIMMER
GLOW
GONG
GRACE
GRACEFUL
GRATITUDE
GROTTO
GROUND
GROVE
GURGLE
GUST
HARMONY
HAVEN
HEATHER
HEAVEN
HERON
HIBISCUS
HOLY
HONEY
HORIZON
HUMBLE
HUSH
HUSHED
INCENSE
INFINITE
INFINITY
INHALE
INSIGHT
INSPIRE
IVORY
IVY
JASMINE
JONQUIL
JOY
KINDNESS
LAKE
LANTERN
LAVENDER
LEAF
LIBERATE
LIGHT
LILY
LIMITLESS
LINEN
LOOSEN
LOTUS
LOVE
LULLABY
LUMINOUS
MAGNOLIA
MANTRA
MAPLE
MARIGOLD
MEADOW
MELLOW
MELODY
MINDFUL
MINIMAL
MINT
MIST
MODEST
MOON
MOONLIGHT
MOSS
MOUNTAIN
MURMUR
MUSIC
MUTED
NECTAR
NESTLE
NICHE
NIRVANA
NUANCE
NURTURE
OASIS
OCEAN
OPENNESS
ORCHARD
ORCHID
PAGODA
PALE
PARADISE
PASTEL
PASTURE
PATHWAY
PATIENT
PATIO
PAVILION
PEACE
PEAK
PEBBLE
PERGOLA
PERSIST
PETAL
PINE
PLAIN
PLATEAU
PLUSH
POISE
POLISH
POLLEN
POND
POPPY
PRAIRIE
PRAYER
PRESENCE
PRIMROSE
PURE
QUIET
RADIANCE
RAIN
REED
REFINE
REFUGE
REJOICE
RELAX
RELEASE
REST
RETREAT
RHYTHM
RIDGE
RIPPLE
RIVER
ROCK
ROOT
ROSEMARY
RUSHES
SACRED
SAGE
SANCTUARY
SAND
SATISFY
SEED
SERENE
SHIMMER
SHORE
SILENCE
SILK
SIMPLE
SKY
SLEEPY
SLUMBER
SMOOTH
SNUG
SNUGGLE
SOARING
SOFT
SOLITUDE
SOOTHE
SOUL
SPACIOUS
SPARKLE
SPIRIT
SPRING
SPROUT
STAR
STARLIGHT
STEADY
STEPPING
STILL
STILLNESS
STONE
STREAM
STRETCH
SUBTLE
SUMMIT
SUNFLOWER
SUNRISE
SUNSET
SWAN
SWIRL
SYMPHONY
TENDER
TERRACE
THISTLE
THYME
TIDE
TRANQUIL
TRANSCEND
TREASURE
TRELLIS
TRICKLE
TULIP
TWILIGHT
UNITY
UNIVERSE
UNWIND
UPLIFT
VALLEY
VANILLA
VAST
VELVET
VERANDA
VINE
VINEYARD
WARM
WARMTH
WAVE
WHISPER
WHOLE
WILLOW
WIND
WINGS
WISDOM
WISTERIA
WOODLAND
YAWN
```

- [ ] **Step 2: Write the failing test for corpus-membership**

Add to `Tests/LevelGenTests/ThemeLexiconTests.swift`. Scoped to zen only —
the doom lexicon isn't grown until Task 3, and (discovered while executing
this plan) the *old* 86-word doom lexicon actually contains two words
(`SEPULCHRE`, `SIGIL`) that aren't present in the regenerated corpus, so a
`Theme.allCases`-spanning version of this test would fail here for reasons
Task 3 fixes, not this task:

```swift
    func test_everyZenLexiconWordIsInTheGeneralCorpus() {
        for word in ThemeLexicon.shared.words(for: .zen) {
            XCTAssertTrue(GeneralWordList.shared.contains(word), "\(word) (zen) not in the general corpus")
        }
    }
```

- [ ] **Step 3: Run the tests**

Run: `swift test --filter ThemeLexiconTests`
Expected: PASS (all existing tests plus the new one — every zen word was validated against the corpus during this plan's research)

- [ ] **Step 4: Commit**

```bash
git add Sources/LevelGen/Resources/seed-zen.txt Tests/LevelGenTests/ThemeLexiconTests.swift
git commit -m "feat(levelgen): grow the Zen theme lexicon (85 -> 331 words)"
```

---

### Task 3: Grow the Doom theme lexicon

**Files:**
- Modify: `Sources/LevelGen/Resources/seed-doom.txt` (replace content)

**Interfaces:**
- Consumes: `Sources/LevelGen/Resources/words.txt` (Task 1) — every word below was validated present in the regenerated corpus during this plan's research.
- Produces: `ThemeLexicon.words(for: .doom)` (existing, unchanged) now returns 298 words instead of 86.

- [ ] **Step 1: Replace `seed-doom.txt`'s content**

Replace `Sources/LevelGen/Resources/seed-doom.txt` with exactly this content (298 words, one per line, alphabetically sorted, confirmed disjoint from the Task 2 zen list — every word already confirmed present in the Task 1-regenerated `words.txt`):

```
ABANDONED
ABYSS
AGONY
ALTAR
AMULET
ANGELIC
ANGUISH
ARCANE
ARTIFACT
ASH
ATONEMENT
BANISH
BANSHEE
BARREN
BASILISK
BATTLE
BEAST
BLASPHEMY
BLAST
BLAZE
BLEAK
BLEEDING
BLIGHTED
BLOOD
BONE
BREACH
BRIMSTONE
BRUTAL
BUNKER
CADAVER
CARNAGE
CASKET
CATACLYSM
CELESTIAL
CHANT
CHARM
CHARRED
CHASM
CHIMERA
CINDER
CLAW
COFFIN
COLLAPSE
CONCEALED
CONFLICT
CONJURE
CONQUEST
CONTAGION
CORPSE
CORRUPT
COVEN
CRACK
CREATURE
CRUELTY
CRUMBLE
CRUMBLING
CRYPT
CRYPTIC
CULTIST
CURSE
CURSED
CYCLONE
CYCLOPS
DAMNATION
DAMNED
DECAY
DECREPIT
DEFILE
DELUGE
DEMON
DERELICT
DESECRATE
DESOLATE
DESPAIR
DESTINY
DETONATE
DEVIL
DISASTER
DISEASE
DISMAL
DOOM
DOOMED
DRAGON
DREAD
DREARY
DRIFTER
DROUGHT
EERIE
ELIXIR
EMACIATED
EMBER
EMPTY
ENIGMA
ESOTERIC
EVIL
EXILE
EXPLOSION
FALLEN
FALLOUT
FAMINE
FAMISHED
FANG
FATED
FEAR
FERAL
FESTER
FESTERING
FESTIVAL
FIEND
FIRE
FLAME
FLOOD
FOLKLORE
FORBIDDEN
FORLORN
FORSAKEN
FRACTURE
FRIGHT
FUNERAL
FURY
GARGOYLE
GATHERING
GAUNT
GHOST
GHOUL
GLOOMY
GOBLIN
GORE
GORGON
GRAVE
GREMLIN
GRIEF
GRIFFIN
GRIM
GROWL
HAGGARD
HATRED
HAUNT
HEARSE
HERETIC
HIDDEN
HOLLOW
HOPELESS
HORN
HORROR
HOWL
HUNT
HURRICANE
HYDRA
IMPACT
INFECTED
INFECTION
INFERNAL
INFERNO
INVASION
INVOKE
JUDGMENT
LEGEND
LIMBO
LURK
MAGIC
MALICE
MASSACRE
MEDUSA
MERCILESS
MIDNIGHT
MISERABLE
MONSTER
MOROSE
MOURNING
MUTANT
MUTATION
MYSTERY
NIGHTMARE
NOMAD
NOXIOUS
OCCULT
OFFERING
OGRE
OMEN
OMINOUS
OUTBREAK
OUTCAST
PANIC
PENANCE
PHANTOM
PLAGUE
POISON
PORTENT
POSSESS
POTION
PRIMAL
PROFANE
PROPHECY
PROWL
PURGATORY
PUTRID
QUAKE
RADIATION
RAGE
RECKONING
RELICS
REMNANTS
RITUAL
ROTTEN
RUBBLE
RUIN
RUINS
RUMOR
RUNE
RUPTURE
RUTHLESS
SACRIFICE
SACRILEGE
SALVATION
SAVAGE
SCALE
SCAR
SCAVENGER
SCORCHED
SCROLL
SECRET
SERPENT
SHADE
SHADOW
SHATTER
SHELTER
SHRINE
SIEGE
SINISTER
SKELETON
SKULL
SLAUGHTER
SMOKE
SNARL
SOMBER
SORCERY
SORROW
SPECTER
SPELL
SPHINX
SPITE
SPLINTER
STALK
STARVING
STORM
SUFFERING
SULFUR
SUMMON
SURVIVOR
TABOO
TAIL
TAINTED
TALISMAN
TALON
TEMPEST
TEMPLE
TERROR
TOMB
TOME
TORMENT
TORNADO
TORTURE
TOXIN
TREMOR
TROLL
UNCANNY
UNHOLY
UNKNOWN
UNSEEN
UNTAMED
UPHEAVAL
VACANT
VAMPIRE
VENGEANCE
VENOM
VICTIM
VILE
VIOLENCE
VOID
WANDERER
WARNING
WASTELAND
WEATHERED
WEREWOLF
WICKED
WING
WITCHING
WITHERED
WOLF
WORSHIP
WOUND
WRAITH
WRATH
WRECK
WRECKAGE
WRETCHED
ZOMBIE
```

- [ ] **Step 2: Run the tests**

Run: `swift test --filter ThemeLexiconTests`
Expected: PASS (all tests, including `test_everyLexiconWordIsInTheGeneralCorpus` from Task 2, now covering both themes)

- [ ] **Step 3: Verify no cross-theme overlap**

Run this one-off check (not a permanent test — the existing lists are static resource files, and this is a content-authoring invariant, not runtime behavior):

```bash
comm -12 Sources/LevelGen/Resources/seed-zen.txt Sources/LevelGen/Resources/seed-doom.txt
```

Expected: no output (empty — confirms zero words appear in both files, matching the existing invariant the previous 85/86-word lists already held).

- [ ] **Step 4: Commit**

```bash
git add Sources/LevelGen/Resources/seed-doom.txt
git commit -m "feat(levelgen): grow the Doom theme lexicon (86 -> 298 words)"
```

---

### Task 4: ESDB attribution notice

**Files:**
- Create: `THIRD_PARTY_NOTICES.md`

**Interfaces:** None — documentation only.

- [ ] **Step 1: Create the notice file**

Create `THIRD_PARTY_NOTICES.md` at the repo root:

```markdown
# Third-Party Notices

## ESDB (formerly SCOWL)

`Sources/LevelGen/Resources/words.txt`, `common-words.txt`, `seed-zen.txt`,
and `seed-doom.txt` are derived from the English Speller Database (ESDB,
previously known as SCOWL), <https://github.com/en-wl/wordlist>.

```
Copyright 2000-2026 by Kevin Atkinson

Permission to use, copy, modify, distribute, and sell any part of the English
Speller Database (ESDB, previously known as SCOWLv2), or word lists
created from it, is hereby granted without fee, provided that the above
copyright notice appears in all copies and that both the above copyright
notice and this notice appear in supporting documentation.  Kevin Atkinson
makes no representations about the suitability of this database for any
purpose.  It is provided "as is" without express or implied warranty.

ESDB is derived from many sources, most of which are in the Public Domain.
Data from the Corpus of Contemporary American English (COCA) was also used.

All data from COCA comes from 3-gram data that is not freely available;
however, the usage is within the rights given by the NDA that was signed when
purchasing the data.  More information on COCA is available at
https://www.english-corpora.org/coca/.

The primary source of words for ESDB comes from 12dicts and ENABLE2K.  Both
are in the Public Domain, but Alan Beale <biljir@pobox.com> deserves special
credit as he is the author of 12dicts and a major contributor to ENABLE2K.  In
addition, he gave me an incredible amount of feedback and created a number of
special lists in order to help improve the overall quality of ESDB.
```
```

- [ ] **Step 2: Commit**

```bash
git add THIRD_PARTY_NOTICES.md
git commit -m "docs: add ESDB third-party attribution notice"
```

---

### Task 5: Full regression pass

**Files:** none (verification only)

**Interfaces:** none — this task runs every test that depends on the word corpus (directly or via procedural generation) to confirm the corpus swap didn't break anything.

- [ ] **Step 1: Run the full Swift package test suite**

Run: `swift test`

Expected: all tests pass, including every test that exercises procedural generation end-to-end against the new corpus:
- `GeneralWordListTests`, `CommonWordsTests`, `ThemeLexiconTests` (this plan's own direct tests)
- `SolvabilitySweepTests` (generates dozens of levels across every band/theme and checks every placed word is real and buildable)
- `WordPoolBuilderTests`, `DeterministicWordProviderTests` (word-pool ranking against the corpus)
- `CrosswordLayoutEngineTests` (grid layout from a word pool)
- `ProceduralGeneratorTests`, `ProceduralGeneratorCapstoneTests`, `ProceduralLevelLibraryTests`, `PackCatalogTests` (full level generation)
- `WheelPickerTests`, `WheelPickerSceneTests`, `SceneCreaturePickerTests`, `SceneLexiconTests`, `ThemePoolsTests` (wheel/scene selection, which read the grown theme lexicons)
- `LevelGenErrorTests`, `VisualPromptsTests`, `ThemeTests`, `PrimesTests` (unaffected by this change, but part of the full suite)
- `WordOfTheDayTests`, `WordOfTheDayImagesTests`, `WordOfTheDaySolvabilityTests` (from the concurrent Word-of-the-Day feature, if that branch has been merged by the time this task runs — these use their own separate curated lists, `daily-zen.txt`/`daily-doom.txt`, untouched by this plan, but their solvability check also reads `GeneralWordList`)

If any test fails, read its failure message carefully — a corpus swap can occasionally surface a test that assumed a specific word from the *old* corpus was present/absent (e.g. a hardcoded example word). Fix by updating that test's example word to one confirmed present in the new corpus, not by loosening the assertion.

- [ ] **Step 2: Confirm no regressions, no commit needed**

This task is a verification gate — if Step 1 passes cleanly, there's nothing to commit. If a test needed a word swap to keep passing, commit that specific fix with a message explaining which test and why (e.g. `fix(levelgen): update WordPoolBuilderTests example word for the new ESDB corpus`).
