# ZenWordOfDoom

iOS word-puzzle game (SwiftUI app in `App/ZenWordOfDoom/`, shared logic in
SPM packages under `Sources/`). The Xcode project is generated — edit
`project.yml`, never a checked-in `.xcodeproj` (run `xcodegen generate`
locally; CI/Xcode Cloud regenerate it themselves).

Key docs: `docs/ARCHITECTURE.md`, `docs/SPEC.md`, `docs/CI.md`,
`docs/ACCESSIBILITY.md`.

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
