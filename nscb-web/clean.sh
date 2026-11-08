#!/usr/bin/env bash
# NSC_BUILDER Web UI — clean build & temp artifacts (pairs with start.sh / dotnet build).
# Removes: bin/, obj/, dist/, itest_out/, _verify_out/, stray logs/tmp. Leaves source only.
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "dotnet clean (Release)..."
dotnet clean -c Release >/dev/null 2>&1 || true

echo "removing build caches, publish output, and test/temp artifacts..."
# build caches
find . -type d \( -name bin -o -name obj \) -prune -exec rm -rf {} + 2>/dev/null || true
# publish output + test scratch + stray temp/logs at any depth under nscb-web
rm -rf dist itest_out _verify_out pack_output.* nohup.out 2>/dev/null || true
find . -type d \( -name itest_out -o -name _verify_out \) -prune -exec rm -rf {} + 2>/dev/null || true
find . -type f \( -name '*.log' -o -name '*.tmp' -o -name 'nohup.out' \) -delete 2>/dev/null || true

echo "clean. Remaining = source only (git status should be clear of artifacts)."
