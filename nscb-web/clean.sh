#!/usr/bin/env bash
# NSC_BUILDER Web UI — clean build & temp artifacts (pairs with start.sh / dotnet build).
# Removes: bin/, obj/, dist/, itest_out/, _verify_out/, stray logs/tmp. Leaves source only.
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "dotnet clean (Release)..."
dotnet clean -c Release >/dev/null 2>&1 || true

echo "removing build caches, publish output, and test/temp artifacts..."
# build caches — skip node_modules/.git so nested bin/ dirs are never touched
find . \( -name node_modules -o -name .git \) -prune -o -type d \( -name bin -o -name obj \) -exec rm -rf {} + 2>/dev/null || true
# publish output + test scratch + stray temp/logs at any depth under nscb-web
rm -rf dist itest_out _verify_out pack_output.* nohup.out 2>/dev/null || true
find . \( -name node_modules -o -name .git \) -prune -o -type d \( -name itest_out -o -name _verify_out \) -exec rm -rf {} + 2>/dev/null || true
find . \( -name node_modules -o -name .git \) -prune -o -type f \( -name '*.log' -o -name '*.tmp' -o -name 'nohup.out' \) -print -delete 2>/dev/null || true

echo "clean. Remaining = source only (git status should be clear of artifacts)."
