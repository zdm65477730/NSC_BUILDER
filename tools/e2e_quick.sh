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
# Stage ONE real DLC (raw .nsz/.nsp, no decompress) into a subdir so the recursive PackName_composition E2E
# case can classify it. The other E2E cases use top-level Samples() (non-recursive) → unaffected.
DLCFILE=$(for r in $LIB; do [ -d "$r" ] || continue; find "$r" -maxdepth 3 -type f \( -iname '*.nsz' -o -iname '*.nsp' \) 2>/dev/null | grep -iE 'dlc'; done | head -1)
if [ -n "$DLCFILE" ]; then mkdir -p "$SCRATCH/_dlc"; cp "$DLCFILE" "$SCRATCH/_dlc/" && echo "  staged DLC for composition E2E: $(basename "$DLCFILE")"; else echo "  (no DLC under LIB; PackName_composition E2E will skip its assert)"; fi
echo "scratch   : $(ls "$SCRATCH" | tr '\n' ' ')"

# 4) run E2E (build the test dll — do NOT use --no-build, clean.sh may have wiped bin/obj)
echo "=== running E2E (FAST=$FAST) ==="
NSCB_E2E_DIR="$SCRATCH" NSCB_E2E_FAST="$FAST" dotnet test -c Release --filter "Category=E2E" 2>&1 \
  | tee /tmp/nscb_e2e_quick.log | grep -iE "Passed!|Failed!|Passed Nscb|Failed Nscb|SKIPPED|content-hash|error CS" | tail -20
rc=${PIPESTATUS[0]}
echo "=== e2e_quick: E2E suite exit=$rc ==="

# 5) real pack-name regression: a base+update+DLC triple must classify as (…+1D) via /api/packname.
#    Uses raw .nsz/.nsp (packname only reads the cnmt headers → fast, no decompression, independent of the E2E pair).
if [ "$rc" = 0 ]; then
  echo "=== pack-name G/U/D regression ==="
  TB=""; TU=""; TD=""
  for root in $LIB; do
    [ -d "$root" ] || continue
    while IFS= read -r g; do
      b=$(find "$g" -maxdepth 1 -type f \( -iname '*base*.nsp' -o -iname '*base*.nsz' \) 2>/dev/null | head -1)
      [ -z "$b" ] && b=$(find "$g" -maxdepth 1 -type f \( -iname '*v0*.nsp' -o -iname '*v0*.nsz' \) 2>/dev/null | grep -ivE 'upd|dlc' | head -1)
      u=$(find "$g" -maxdepth 1 -type f \( -iname '*upd*.nsp' -o -iname '*upd*.nsz' \) 2>/dev/null | head -1)
      d=$(find "$g" -maxdepth 3 -type f \( -iname '*.nsz' -o -iname '*.nsp' \) 2>/dev/null | grep -iE 'dlc' | head -1)
      [ -z "$b" ] || [ -z "$u" ] || [ -z "$d" ] && continue
      sz=$(stat -c%s "$d" 2>/dev/null || echo 999999999999)   # prefer the smallest DLC (headers-only, but keep it light)
      if [ -z "$TD" ] || [ "$sz" -lt "$(stat -c%s "$TD" 2>/dev/null || echo 0)" ]; then TB="$b"; TU="$u"; TD="$d"; fi
    done < <(find "$root" -maxdepth 1 -type d 2>/dev/null)
  done
  if [ -z "$TD" ]; then
    echo "  SKIP: no base+upd+DLC triple found under LIB — pack-name D-check not applicable"
  else
    pkill -f 'NscbServer' 2>/dev/null; sleep 1
    dotnet run -c Release --project src/NscbServer -f net10.0 -- --no-open >/tmp/nscb_eq_srv.log 2>&1 &
    SPID=$!
    ok=0; for i in $(seq 1 40); do [ "$(curl -s -m2 -o /dev/null -w '%{http_code}' http://127.0.0.1:54321/api/settings)" = "200" ] && { ok=1; break; }; sleep 1; done
    if [ "$ok" = 1 ]; then
      curl -s -m5 -X PUT http://127.0.0.1:54321/api/settings -H 'Content-Type: application/json' --data "{\"prodKeysPath\":\"$KEYS\"}" >/dev/null
      PN=$(python3 - "$TB" "$TU" "$TD" <<'PY' | tr -d '\r'
import sys, json, urllib.request
payload = json.dumps({"inputs": sys.argv[1:4]}).encode()
req = urllib.request.Request("http://127.0.0.1:54321/api/packname", data=payload, headers={"Content-Type": "application/json"})
print(urllib.request.urlopen(req, timeout=30).read().decode())
PY
)
      echo "  packname: $PN"
      if echo "$PN" | grep -q '1D'; then echo "  OK: DLC counted in pack name"; else echo "  FAIL: pack name missing (1D)"; rc=1; fi
    else
      echo "  SKIP: server did not start (port busy?) — pack-name check not run"
    fi
    kill "$SPID" 2>/dev/null; wait "$SPID" 2>/dev/null
  fi
fi

echo "=== e2e_quick: final exit=$rc ==="
exit "$rc"
