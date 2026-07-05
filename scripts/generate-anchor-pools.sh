#!/bin/sh
# Regenerates Sources/LevelGen/Resources/anchor-pools.json — the pre-selected
# "known good" wheel anchors, quality-gated against the game's own corpus
# (words.txt + common-words.txt, both ESDB-derived; see
# generate-word-corpus.sh). Run after any corpus regeneration.
#
# Pools are TIERED by richness (how many COMMON words the anchor's letters
# build, lengths 3..N): a rich pool is an easy level (plenty to find), a lean
# pool is a hard one (few possible words, same grid demands). Per length:
#
#   length   easy      medium    hard      <- common-buildable pool size
#     5      >= 20     14-19      9-13
#     6      >= 35     22-34     14-21
#     7      >= 60     38-59     24-37
#     8      >= 90     55-89     34-54
#     9      >= 120    75-119    45-74
#
# Every anchor must also pass sanity gates (it is the guaranteed pangram on
# capstone/boss levels): it is itself a COMMON word, has at least one vowel,
# at least three distinct letters, and no letter more than twice (kills
# degenerate wheels like XVIII).
#
# Anchors are de-duplicated by letter multiset (two anagrams are the same
# wheel) and capped at 200 per (length, tier) — easy/medium keep their
# richest members, hard keeps its leanest, so each tier caps toward its own
# character. Output is sorted alphabetically per tier for stable diffs.
set -eu

cd "$(dirname "$0")/.."
RESOURCES="Sources/LevelGen/Resources"

python3 << 'EOF'
import collections, itertools, json

R = "Sources/LevelGen/Resources/"
# (length) -> [(tier, min_common, max_common)]; easy has no upper bound.
TIERS = {
    5: [("easy", 20, None), ("medium", 14, 19), ("hard", 9, 13)],
    6: [("easy", 35, None), ("medium", 22, 34), ("hard", 14, 21)],
    7: [("easy", 60, None), ("medium", 38, 59), ("hard", 24, 37)],
    8: [("easy", 90, None), ("medium", 55, 89), ("hard", 34, 54)],
    9: [("easy", 120, None), ("medium", 75, 119), ("hard", 45, 74)],
}
CAP = 200
VOWELS = set("AEIOU")

corpus = [w.strip() for w in open(R + "words.txt") if w.strip()]
common = set(w.strip() for w in open(R + "common-words.txt") if w.strip())
sig_common = collections.Counter("".join(sorted(w)) for w in corpus if w in common)

def sane(word):
    counts = collections.Counter(word)
    return (len(counts) >= 3
            and any(ch in VOWELS for ch in word)
            and max(counts.values()) <= 2)

def common_buildable(anchor):
    # Count buildable common words by enumerating the anchor's sub-multisets
    # (<= 2^9 combos) against a signature index — avoids scanning the corpus
    # per anchor.
    letters = sorted(anchor)
    seen, total = set(), 0
    for k in range(3, len(letters) + 1):
        for combo in itertools.combinations(letters, k):
            s = "".join(combo)
            if s not in seen:
                seen.add(s)
                total += sig_common.get(s, 0)
    return total

by_len = {n: {} for n in TIERS}
for w in sorted(corpus):  # sorted => deterministic multiset representative
    n = len(w)
    if n in by_len and w in common and sane(w):
        by_len[n].setdefault("".join(sorted(w)), w)

pools = {}
for n, tiers in TIERS.items():
    scored = [(common_buildable(w), w) for w in by_len[n].values()]
    out = {}
    for tier, lo, hi in tiers:
        members = [(c, w) for c, w in scored if c >= lo and (hi is None or c <= hi)]
        # easy/medium keep their richest members; hard keeps its leanest.
        members.sort(key=lambda x: (x[0] if tier == "hard" else -x[0], x[1]))
        out[tier] = sorted(w for _, w in members[:CAP])
        print(f"len {n} {tier:6}: {len(members)} candidates -> kept {len(out[tier])}")
    pools[str(n)] = out

with open(R + "anchor-pools.json", "w") as f:
    json.dump(pools, f, indent=1, sort_keys=True)
    f.write("\n")
print("wrote", R + "anchor-pools.json")
EOF
