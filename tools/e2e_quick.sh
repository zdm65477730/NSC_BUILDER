#!/usr/bin/env bash
# ── Quick real-sample E2E ──────────────────────────────────────────────────────────
# Finds the SMALLEST game folder that has both a [BASE] application and a [UPD]
# update (NSC_BUILDER naming), decompresses .nsz→.nsp as needed into a scratch dir,
# then runs the IntegrationE2E suite. Fast mode by default (≈3× quicker). Cleans the
# scratch on exit unless KEEP=1.
#
# Usage:   ./tools/e2e_quick.sh
# Env:     E2E_QUICK_LIB   space-separated library dirs to scan (default below)
#          E2E_QUICK_KEYS  path to prod.keys (auto-detected if unset)
#          E2E_QUICK_FAST  1=fast matrix (default), 0=full {12,17}×{1,6}
#          E2E_QUICK_DIR   scratch dir (default /tmp/nscb_e2e_samples)
#          E2E_QUICK_KEEP  1=keep scratch after run
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."          # → repo root

LIB="${E2E_QUICK_LIB:-/mnt/e/游戏/NS/NS /mnt/d/111}"
FAST="${E2E_QUICK_FAST:-1}"
SCRATCH="${E2E_QUICK_DIR:-/tmp/nscb_e2e_samples}"
KEEP="${E2E_QUICK_KEEP:-0}"

cleanup() { [ "$KEEP" != 1 ] && rm -rf "$SCRATCH" 2>/dev/null || echo "  kept scratch: $SCRATCH"; }
trap cleanup EXIT

# 1) prod.keys ──────────────────────────────────────────────────────────────────────
KEYS="${E2E_QUICK_KEYS:-}"
if [ -z "$KEYS" ] || [ ! -f "$KEYS" ]; then
  KEYS=$(for b in /mnt/d /mnt/c; do find "$b" -maxdepth 4 -iname 'prod.keys' 2>/dev/null; done | grep -v '\$RECYCLE' | head -1)
fi
if [ -z "${KEYS:-}" ] || [ ! -f "$KEYS" ]; then echo "ERROR: prod.keys not found (set E2E_QUICK_KEYS)"; exit 2; fi
echo "prod.keys : $KEYS"

# 2) smallest [BASE]+[UPD] pair ─────────────────────────────────────────────────────
best=""; bestsz=""; BB=""; BU=""
for root in $LIB; do
  [ -d "$root" ] || continue
  while IFS= read -r g; do
    base=$(find "$g" -maxdepth 1 -type f \( -iname '*base*.nsp' -o -iname '*base*.nsz' \) 2>/dev/null | head -1)
    [ -z "$base" ] && base=$(find "$g" -maxdepth 1 -type f \( -iname '*[v0].nsp' -o -iname '*[v0].nsz' \) 2>/dev/null | head -1)
    upd=$(find "$g" -maxdepth 1 -type f \( -iname '*upd*.nsp' -o -iname '*upd*.nsz' \) 2>/dev/null | head -1)
    [ -z "$base" ] || [ -z "$upd" ] && continue
    sz=$(stat -c%s "$base" 2>/dev/null || echo 999999999999)
    if [ -z "$bestsz" ] || [ "$sz" -lt "$bestsz" ]; then best="$g"; bestsz="$sz"; BB="$base"; BU="$upd"; fi
  done < <(find "$root" -maxdepth 1 -type d 2>/dev/null)
done
if [ -z "${best:-}" ]; then echo "ERROR: no [BASE]+[UPD] game pair found under: $LIB"; exit 3; fi
echo "pair      : $(basename "$best")  (base $(numfmt --to=iec "$bestsz" 2>/dev/null || echo "$bestsz" B))"
echo "  base: $BB"
echo "  upd : $BU"

# 3) build itest (nsz→nsp) + stage samples ──────────────────────────────────────────
dotnet build tools/itest -c Release -v q >/dev/null 2>&1 || { echo "ERROR: itest build failed"; exit 4; }
rm -rf "$SCRATCH"; mkdir -p "$SCRATCH"
cp "$KEYS" "$SCRATCH/prod.keys"

place() {   # $1=src  $2=dest-stem  $3=keep-original-ext(1/0)
  local src="$1" stem="$2" ext="${1##*.}"
  [ "$3" = 1 ] && cp "$src" "$SCRATCH/$stem.$ext"
  if [ "$ext" = "nsp" ]; then cp "$src" "$SCRATCH/$stem.nsp"
  else echo "  decompressing $stem …"; dotnet run --no-build -c Release --project tools/itest -- nsz2nsp "$src" "$SCRATCH/$stem.nsp" --keys="$KEYS" >/dev/null 2>&1
       [ -f "$SCRATCH/$stem.nsp" ] || { echo "ERROR: decompress failed for $src"; exit 5; }
  fi
}
place "$BB" base 1     # keep base.nsz too (NSZ/XCZ samples) ; derive base.nsp
place "$BU" upd  0     # only need upd.nsp for the merge pair
echo "scratch   : $(ls "$SCRATCH" | tr '\n' ' ')"

# 4) run E2E (build the test dll — do NOT use --no-build, clean.sh may have wiped bin/obj)
echo "=== running E2E (FAST=$FAST) ==="
NSCB_E2E_DIR="$SCRATCH" NSCB_E2E_FAST="$FAST" dotnet test -c Release --filter "Category=E2E" 2>&1 \
  | tee /tmp/nscb_e2e_quick.log | grep -iE "Passed!|Failed!|Passed Nscb|Failed Nscb|SKIPPED|content-hash|error CS" | tail -20
rc=${PIPESTATUS[0]}
echo "=== e2e_quick: exit=$rc ==="
exit "$rc"
