#!/bin/sh
# Bump the app version in project.yml for a release.
#
# Usage:
#   scripts/bump-version.sh [patch|minor|major]
#
# The bump level defaults to "patch":
#   patch  0.1.0 -> 0.1.1   (default)
#   minor  0.1.3 -> 0.2.0
#   major  0.4.2 -> 1.0.0
#
# It rewrites two settings in project.yml:
#   MARKETING_VERSION        the semantic version shown to users (X.Y.Z)
#   CURRENT_PROJECT_VERSION  the build number — bumped by 1 every release
#                            because TestFlight rejects a re-used build number.
#
# Regenerate the Xcode project afterwards (CI / Xcode Cloud do this for you):
#   xcodegen generate
set -eu

part="${1:-patch}"
case "$part" in
  patch|minor|major) ;;
  *) echo "usage: $(basename "$0") [patch|minor|major]" >&2; exit 2 ;;
esac

cd "$(dirname "$0")/.."
project="project.yml"

current=$(grep -E '^[[:space:]]*MARKETING_VERSION:' "$project" | head -1 \
  | sed -E 's/.*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/')
build=$(grep -E '^[[:space:]]*CURRENT_PROJECT_VERSION:' "$project" | head -1 \
  | sed -E 's/.*"([0-9]+)".*/\1/')

if ! printf '%s' "$current" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "error: could not read a X.Y.Z MARKETING_VERSION from $project" >&2
  exit 1
fi

major=${current%%.*}
rest=${current#*.}
minor=${rest%%.*}
patch=${rest#*.}

case "$part" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
esac

new="${major}.${minor}.${patch}"
newbuild=$((build + 1))

tmp=$(mktemp)
sed -E \
  -e "s/(MARKETING_VERSION: )\"[0-9]+\.[0-9]+\.[0-9]+\"/\1\"${new}\"/" \
  -e "s/(CURRENT_PROJECT_VERSION: )\"[0-9]+\"/\1\"${newbuild}\"/" \
  "$project" > "$tmp" && mv "$tmp" "$project"

echo "MARKETING_VERSION       ${current} -> ${new}"
echo "CURRENT_PROJECT_VERSION ${build} -> ${newbuild}"
echo
echo "Next, to cut the release:"
echo "  git commit -am \"Release v${new}\""
echo "  git tag v${new} && git push --follow-tags"
