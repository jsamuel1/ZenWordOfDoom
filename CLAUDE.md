# ZenWordOfDoom

iOS word-puzzle game (SwiftUI app in `App/ZenWordOfDoom/`, shared logic in
SPM packages under `Sources/`). The Xcode project is generated — edit
`project.yml`, never a checked-in `.xcodeproj` (run `xcodegen generate`
locally; CI/Xcode Cloud regenerate it themselves).

Key docs: `docs/ARCHITECTURE.md`, `docs/SPEC.md`, `docs/CI.md`,
`docs/ACCESSIBILITY.md`.

## Release procedure

Releases are cut by merging the work to `main` directly — do NOT open a
pull request for the release.

1. Finish and commit all work on your feature branch.
2. Bump the version:

   ```sh
   scripts/bump-version.sh [patch|minor|major]   # defaults to patch
   ```

   This rewrites `MARKETING_VERSION` (user-facing X.Y.Z) and
   `CURRENT_PROJECT_VERSION` (build number, +1 every release — TestFlight
   rejects re-used build numbers) in `project.yml`.
3. Commit the bump as the release commit:

   ```sh
   git commit -am "Release vX.Y.Z"
   ```

4. Merge to `main` (direct merge, not a PR) and push:

   ```sh
   git fetch origin main
   git checkout main && git merge <feature-branch>
   git push origin main
   ```

5. Tag the release commit on `main` and push the tag:

   ```sh
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

Note for remote (Claude Code on the web) sessions: branch pushes work
(including `main`, when the user has authorized it) but pushes to
`refs/tags/*` are rejected with HTTP 403. For step 5, trigger the
`Tag Release` workflow (`.github/workflows/tag-release.yml`) instead —
via the GitHub MCP `actions_run_trigger` tool or
`gh workflow run tag-release.yml` — passing `tag: vX.Y.Z` and `ref:` the
full SHA of the `Release vX.Y.Z` commit on `main`. Verify afterwards with
`git ls-remote origin refs/tags/vX.Y.Z`.
