#!/bin/sh
# Xcode Cloud — post-clone step.
#
# The Xcode project is NOT committed; it is generated from project.yml by
# XcodeGen (see docs/CI.md). Xcode Cloud clones the repo and then looks for
# ZenWordOfDoom.xcodeproj, so we must generate it here, before the build
# starts. This script runs automatically after Xcode Cloud clones the repo.
set -e

# Make sure Homebrew is on PATH (Apple Silicon Xcode Cloud images install it
# at /opt/homebrew but don't always export it into this script's shell).
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "Installing XcodeGen…"
brew install xcodegen

echo "Generating Xcode project from project.yml…"
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate

echo "Generated $(ls -d *.xcodeproj) with $(xcodebuild -version | tr '\n' ' ')"

# Seed Package.resolved before resolving. The generated .xcodeproj is not
# committed, so it never carries a resolved file into a fresh clone; Xcode
# Cloud archives with automatic package resolution DISABLED and fails outright
# if that file is missing or stale (e.g. after adding GoogleUserMessagingPlatform,
# a plain `-resolvePackageDependencies` here has been seen failing against Xcode
# Cloud's cached dependency state with "a resolved file is required when
# automatic dependency resolution is disabled"). Copying in a known-good,
# hand-maintained resolved file makes resolution deterministic instead of
# depending on that cache. Bump ci_scripts/Package.resolved's pins whenever a
# `packages:` entry in project.yml changes.
echo "Seeding Package.resolved…"
mkdir -p ZenWordOfDoom.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
cp ci_scripts/Package.resolved \
  ZenWordOfDoom.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

echo "Resolving Swift Package dependencies…"
xcodebuild -resolvePackageDependencies \
  -project ZenWordOfDoom.xcodeproj \
  -scheme ZenWordOfDoom
