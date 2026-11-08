#!/usr/bin/env bash
# NSC_BUILDER Web UI - one-click start (Linux/macOS)
# Builds (first time) and launches the server; auto-opens browser.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PORT=54321
URL="http://127.0.0.1:$PORT"
BIN="src/NscbServer/bin/Release/net10.0/NscbServer"

# Build if binary doesn't exist or is older than any source file
needs_build=1
if [ -f "$BIN" ] || [ -f "$BIN.dll" ]; then
  newest_src=$(find src tests -name "*.cs" -newer "$BIN.dll" 2>/dev/null | head -1)
  [ -z "$newest_src" ] && needs_build=0
fi

if [ "$needs_build" = "1" ]; then
  echo "Building NSC_BUILDER Web UI ..."
  dotnet build src/NscbServer/NscbServer.csproj -c Release -f net10.0 -v quiet
  echo "Build done."
fi

# Launch (foreground)
echo "Starting server on $URL  (Ctrl+C to stop)"
# Open browser after a short delay
( sleep 2 && xdg-open "$URL" 2>/dev/null || true ) &

dotnet run --project src/NscbServer -c Release -f net10.0 --no-build -- \
  --urls "http://127.0.0.1:$PORT"
