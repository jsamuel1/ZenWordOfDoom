# ZenWordOfDoom

iOS word-puzzle game (SwiftUI app in `App/ZenWordOfDoom/`, shared logic in
SPM packages under `Sources/`). The Xcode project is generated — edit
`project.yml`, never a checked-in `.xcodeproj` (run `xcodegen generate`
locally; CI/Xcode Cloud regenerate it themselves).

Key docs: `docs/ARCHITECTURE.md`, `docs/SPEC.md`, `docs/CI.md`,
`docs/ACCESSIBILITY.md`.

## Documentation upkeep (do this in the SAME change, not later)

Docs here describe the game **as shipped** and have drifted before. When a
change touches any of the areas below, update its documentation in the same
commit/branch — a code change whose docs still describe the old behavior is
an incomplete change.

- **Gameplay rules** (scoring, doom timer/multiplier, hints, modes,
  progression/difficulty ladder, level formats): update the matching
  `ARCHITECTURE.md` section (§3 engine, §4 generation) AND add/refresh a
  `> **Shipped:** …` amendment under the relevant `SPEC.md` section —
  SPEC keeps the original vision text and records deltas in those quoted
  notes; don't rewrite its history.
- **Economy** (any serenity faucet, sink, price, cap, or starting value):
  the single source of truth is `Sources/GameCore/Economy.swift` — change
  numbers there only, with the doc comment explaining intent. Then update
  `ARCHITECTURE.md` §5.2 (the authoritative numbers table), the SPEC §8
  economy `Shipped:` note, and the pins in
  `Tests/GameCoreTests/EconomyTests.swift` (including the pack-yield
  range test — the design target is ~0.8 hints earned per level). If IAP
  contents change, also update `Products.storekit` descriptions and
  remind the user that App Store Connect metadata must be edited by hand.
- **Art / content pipeline** (scenes, creatures, anchor pools, affinity,
  daily images): update `ARCHITECTURE.md` §4/§4.2. Conventions to
  preserve: an illustration's slug IS its metadata (hyphen-separated
  words drive `SceneAffinity`) — adding art must stay "slug + asset, no
  mapping tables"; anchor pools are regenerated only via
  `scripts/generate-anchor-pools.sh` (never hand-edit
  `anchor-pools.json`), and its thresholds are mirrored in
  `AnchorPoolsTests`.
- **Save format**: additive fields need tolerant decoding
  (`decodeIfPresent ?? default`, see `SaveState`/`LevelProgress`);
  meaning changes need a `SaveState.currentSchemaVersion` bump plus a
  `GameStore.migrated` case — document what the bump resets in both
  places and in `ARCHITECTURE.md` §5.
- `docs/REVIEW.md` is a **dated snapshot** — never retro-edit it; write a
  new dated section/appendix if a fresh assessment is wanted.

## Release procedure

Two steps: land the work on `main` by direct merge (do NOT open a pull
request), then run the `Release` workflow. Do not hand-roll the version
bump, release commit, or tag — the workflow is the single consistent
action that does all three, so they can never drift apart.

1. Merge the release-worthy work to `main` (direct merge, not a PR) and
   push:

   ```sh
   git fetch origin main
   git checkout main && git merge <feature-branch>
   git push origin main
   ```

2. Trigger the `Release` workflow (`.github/workflows/release.yml`) on
   `main`, choosing the bump level (`patch` default / `minor` / `major`):

   - GitHub UI: Actions → Release → Run workflow, or
   - `gh workflow run release.yml -f bump=patch`, or
   - GitHub MCP: `actions_run_trigger` with method `run_workflow`,
     `workflow_id: release.yml`, `ref: main`, inputs `{"bump": "patch"}`.

   The workflow runs `scripts/bump-version.sh` (rewrites
   `MARKETING_VERSION`, the user-facing X.Y.Z, and
   `CURRENT_PROJECT_VERSION`, the build number, +1 every release —
   TestFlight rejects re-used build numbers, in `project.yml`), commits
   `Release vX.Y.Z` to `main`, tags `vX.Y.Z`, and pushes both.

3. Verify the tag landed:

   ```sh
   git ls-remote origin 'refs/tags/v*' | tail -3
   ```

Notes:

- Remote (Claude Code on the web) sessions: branch pushes work (including
  `main`, when the user has authorized it) but pushes to `refs/tags/*`
  are rejected with HTTP 403 — the workflow is the only supported way to
  tag from a remote session.
- The workflow pushes with `GITHUB_TOKEN`, which never triggers other
  GitHub Actions — so its final step explicitly dispatches `ci.yml` on
  the release commit (skipped if a CI run for that commit already exists;
  `ci.yml`'s per-ref concurrency group also collapses any duplicate).
  External integrations with their own GitHub app (e.g. Xcode Cloud)
  receive the push/tag directly and build the release from it.
