# SCOWL/ESDB word corpus upgrade

**Status:** Design approved (brainstorm), pending implementation plan.
**Date:** 2026-07-03

## 1. Summary

Replace the game's three word-list resources with content derived from
**ESDB** (formerly SCOWL, `github.com/en-wl/wordlist`), an actively
maintained, MIT-like-licensed word database with per-word commonality,
dialect, and part-of-speech data — a real quality upgrade over the current
1990s-era ENABLE/Google-10000 sources, and a chance to close a real
provenance gap: neither current resource has a repeatable regeneration
script (both were one-time manual exports), the same situation Word of the
Day just fixed for bundled art.

| File | Current source | New source |
|---|---|---|
| `words.txt` (general corpus) | ENABLE, ~105k words | ESDB size 60, American, 3-9 letters (~74.3k words, real count) |
| `common-words.txt` (familiar-word bias) | Google top-10k | ESDB size 35, American, 3-9 letters (~32.8k words, real count) |
| `seed-zen.txt` / `seed-doom.txt` (theme lexicons) | 85/86 hand-picked words each | Grown as large as good topical candidates allow, each validated against the new general corpus |

The ESDB toolchain (Python + SQLite) is built and available permanently at
`~/src/esdb-wordlist` on the development machine — not vendored into this
repo; only its filtered text output is committed here, exactly as the
current resources already work.

## 2. Goals / non-goals

**Goals**
- Upgrade `words.txt` and `common-words.txt` to ESDB-derived content at the
  sizes validated during brainstorming (60 and 35 respectively, American
  English, 3-9 letters, matching the current files' length filter).
- Grow `seed-zen.txt`/`seed-doom.txt` with topically-curated words (zen:
  calmness/meditation/nature; doom: monsters/post-apocalypse/demons/
  dragons/mystery), every one validated as a real word present in the new
  general corpus — same "no invented words" discipline the codebase already
  enforces everywhere else.
- Add a repeatable generation script so this corpus can be regenerated
  later (e.g. if ESDB updates, or the size tier needs revisiting) without
  redoing this research from scratch.
- Satisfy ESDB's copyright/attribution requirement in the repo.
- Every existing test that depends on the word corpus (`GeneralWordListTests`,
  `CommonWordsTests`, `ThemeLexiconTests`, `SolvabilitySweepTests`,
  `WordPoolBuilderTests`, `CrosswordLayoutEngineTests`,
  `DeterministicWordProviderTests`) must still pass — this is the
  regression net proving the swap didn't break generation for any band or
  theme.

**Non-goals**
- Vendoring the ESDB database or its build toolchain into this repo — it's
  an external tool used to produce the resource, not a runtime or committed
  dependency (same relationship the current `words.txt` already has to
  ENABLE, which isn't vendored either).
- Preserving the exact content of any already-generated, per-device-cached
  level (`GeneratedLevelCache` already isolates this — a level a player has
  already generated keeps its exact original content regardless of corpus
  changes; only not-yet-generated levels pick up the new corpus). Treat this
  corpus swap as a content revision, not a migration.
- Non-American dialects (British/Canadian/Australian spellings) — out of
  scope, matches the current corpus's implicit American-only convention.
- Touching the Word-of-the-Day feature's own curated lists
  (`daily-zen.txt`/`daily-doom.txt`) — those are separate, already complete,
  hand-curated content unrelated to this corpus.

## 3. Key decisions (from brainstorm)

1. **ESDB size 60** (American, `A` spelling, variant-level 1) for the
   general corpus — ESDB's own "medium-large, default spell-checking
   dictionary" tier. Real count at 3-9 letters: **74,302 words**.
2. **ESDB size 35** (American, variant-level 1) for `common-words.txt` —
   ESDB's smallest/strictest tier ("recommended small size"). This is a
   *threshold*, not a frequency rank like the current Google-10000 source,
   so it's a broader "common" definition than today (~32,800 words vs.
   ~8,100) — accepted explicitly as a trade-off for using a single,
   consistent ESDB-derived pipeline instead of a separate frequency list.
3. **Theme lexicons are uncapped** — grow `seed-zen.txt`/`seed-doom.txt` with
   as many good, real, on-theme candidates as can be found and validated,
   rather than a fixed target count.
4. **A new repeatable script** replaces the previous one-time manual export
   pattern for `words.txt`/`common-words.txt`.

## 4. Architecture

### 4.1 Corpus generation (external tool → committed resource)

```
~/src/esdb-wordlist          (external, not part of this repo)
  scowl.db                   built via `make`, already present on this machine
  ./scowl --db scowl.db word-list <size> A 1   extraction command

scripts/generate-word-corpus.sh   (new, in this repo)
  - Reads ESDB's location from an environment variable (e.g. ESDB_DIR,
    defaulting to ~/src/esdb-wordlist) so the script is portable to another
    machine/developer that clones ESDB elsewhere.
  - Runs the size-60 and size-35 extractions, filters each to 3-9 letters,
    uppercases, dedupes, sorts — writing directly to
    Sources/LevelGen/Resources/words.txt and .../common-words.txt.
  - Idempotent/deterministic: same ESDB database + same size/dialect always
    produces the same output; safe to re-run.
```

This mirrors Word of the Day's `scripts/generate-daily-word-images.sh`
pattern (a committed script driving an external tool to produce a committed
resource) rather than the ad-hoc "produced once, no script" precedent both
`words.txt` and the original bundled art had before.

### 4.2 Theme lexicon growth (`seed-zen.txt` / `seed-doom.txt`)

A separate, content-curation step, not part of the ESDB extraction script:

1. Draft topical candidate word lists (zen: calmness, meditation, nature
   vocabulary; doom: monsters, post-apocalypse, demons, dragons, mystery
   vocabulary) — the same brainstorming approach already used successfully
   for Word of the Day's curated lists.
2. Validate every candidate against the **regenerated** `words.txt`
   (§4.1) — a candidate not present in the general corpus is rejected
   (matches `ThemeLexicon`'s implicit contract that theme words are real,
   buildable corpus entries).
3. The surviving, validated candidates become the new
   `seed-zen.txt`/`seed-doom.txt` content (uncapped size per §3.3).

### 4.3 Attribution

ESDB's license requires its copyright notice to appear in "supporting
documentation" for any redistribution of the database or word lists derived
from it. Since this project only uses American English ('A' spelling,
sizes ≤ 80), only ESDB's primary copyright block applies (not the
Australian or UKACD addenda). Add a new top-level `THIRD_PARTY_NOTICES.md`
containing that copyright block verbatim.

## 5. Data flow

1. Developer (or a future session) runs `scripts/generate-word-corpus.sh`,
   pointing at the built ESDB database.
2. Script extracts, filters, and overwrites `words.txt` and
   `common-words.txt` in place.
3. `GeneralWordList`/`CommonWords` (existing Swift loaders, unchanged) load
   the new files exactly as before — no code changes needed there, since
   both already just read whatever uppercase, newline-separated content is
   in the file.
4. Theme lexicon candidates are validated against the new `words.txt` and
   written to `seed-zen.txt`/`seed-doom.txt`; `ThemeLexicon` (unchanged) loads
   them exactly as before.
5. Full existing test suite (§2 Goals) re-run to confirm generation still
   works across every band/theme with the new corpus.

## 6. Risks & open questions

- **"Common" is now a looser threshold than today** (§3.2) — accepted
  trade-off, not a defect; if grid quality noticeably degrades in practice,
  revisit with a stricter size (e.g. 25, if ESDB offers one) as a follow-up.
- **Corpus swap is a content revision, not a migration** — some previously
  "typical" generated levels for a given seed could differ from before for
  players who haven't generated that level yet. Not a goal to prevent (see
  Non-goals); `GeneratedLevelCache` already isolates already-played content.
- **ESDB toolchain is external, machine-local** — `scripts/generate-word-corpus.sh`
  is only runnable on a machine with ESDB cloned/built; this is acceptable
  since it's a one-time-per-revision authoring step, not something CI or
  players ever run, matching how `xcodegen`/`agy` are also machine-local
  authoring tools already used elsewhere in this project's tooling.
- **Theme lexicon curation is manual** — drafting good topical candidates is
  a judgment call, same as it was for Word of the Day's curated lists.

## 7. Testing

- `GeneralWordListTests`, `CommonWordsTests`: existing structural tests
  (non-empty, real-word spot checks) must still pass against the new files.
- `ThemeLexiconTests`: existing tests (non-empty, uppercase, case-insensitive
  membership) must still pass against the grown lexicons.
- `SolvabilitySweepTests`, `WordPoolBuilderTests`,
  `CrosswordLayoutEngineTests`, `DeterministicWordProviderTests`: the
  broader regression net — every one of these exercises procedural
  generation end-to-end and must still produce valid, solvable levels with
  the new corpus.
- New: a test (or extension of an existing one) asserting every
  `seed-zen.txt`/`seed-doom.txt` entry is present in the regenerated
  `words.txt` — encodes the §4.2 validation contract so a future manual
  edit to either file can't silently violate it.
