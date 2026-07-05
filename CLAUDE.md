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

Note for remote (Claude Code on the web) sessions: push credentials are
often scoped to the session's designated feature branch — pushes to
`main` or `refs/tags/*` may be rejected with HTTP 403. If that happens,
push the release commit to the feature branch and ask the user to run
steps 4-5 locally (or merge via the GitHub API if the user asks).
