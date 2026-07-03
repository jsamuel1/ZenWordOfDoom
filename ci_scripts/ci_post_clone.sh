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

# Resolve Swift Package dependencies now, before the build. The generated
# .xcodeproj is not committed, so its Package.resolved doesn't exist yet; Xcode
# Cloud runs the archive with automatic package resolution DISABLED and fails
# if that file is missing (e.g. GoogleMobileAds / GoogleUserMessagingPlatform).
# Resolving explicitly here writes Package.resolved into the workspace so the
# archive step finds it.
echo "Resolving Swift Package dependencies…"
xcodebuild -resolvePackageDependencies \
  -project ZenWordOfDoom.xcodeproj \
  -scheme ZenWordOfDoom
