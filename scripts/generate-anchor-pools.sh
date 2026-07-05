#!/bin/sh
# Regenerates Sources/LevelGen/Resources/anchor-pools.json — the pre-selected
# "known good" wheel anchors, quality-gated against the game's own corpus
# (words.txt + common-words.txt, both ESDB-derived; see
# generate-word-corpus.sh). Run after any corpus regeneration.
#
# An anchor qualifies for the pool of its length when:
#   - it is itself a COMMON word (recognizable — it is the guaranteed pangram
#     on capstone/boss levels), and
#   - the number of COMMON words buildable from its letters (3..N) meets the
#     per-length floor below — so every wheel has a rich, familiar word pool
#     and the crossword never needs obscure filler:
#         5 -> >= 15    6 -> >= 25    7 -> >= 40    8 -> >= 55    9 -> >= 70
#     (each floor sits well above that length's median candidate; thresholds
#     chosen from the corpus distribution — see docs/REVIEW.md appendix).
#
# Anchors are de-duplicated by letter multiset (two anagrams are the same
# wheel) and capped at the best 250 per length (ranked by common-buildable
# pool size), keeping the bundle small and the guard tests fast. Output is
# sorted alphabetically per length for stable diffs.
set -eu

cd "$(dirname "$0")/.."
RESOURCES="Sources/LevelGen/Resources"

python3 << 'EOF'
import collections, itertools, json

R = "Sources/LevelGen/Resources/"
THRESHOLDS = {5: 15, 6: 25, 7: 40, 8: 55, 9: 70}
CAP = 250

corpus = [w.strip() for w in open(R + "words.txt") if w.strip()]
common = set(w.strip() for w in open(R + "common-words.txt") if w.strip())
sig_common = collections.Counter("".join(sorted(w)) for w in corpus if w in common)

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

by_len = {n: {} for n in THRESHOLDS}
for w in sorted(corpus):  # sorted => deterministic multiset representative
    n = len(w)
    if n in by_len and w in common:
        by_len[n].setdefault("".join(sorted(w)), w)

pools = {}
for n, floor in THRESHOLDS.items():
    scored = [(common_buildable(w), w) for w in by_len[n].values()]
    kept = [(c, w) for c, w in scored if c >= floor]
    kept.sort(key=lambda x: (-x[0], x[1]))
    pools[str(n)] = sorted(w for _, w in kept[:CAP])
    print(f"len {n}: {len(scored)} candidates -> {len(kept)} above floor {floor} -> kept {len(pools[str(n)])}")

with open(R + "anchor-pools.json", "w") as f:
    json.dump(pools, f, indent=1, sort_keys=True)
    f.write("\n")
print("wrote", R + "anchor-pools.json")
EOF
