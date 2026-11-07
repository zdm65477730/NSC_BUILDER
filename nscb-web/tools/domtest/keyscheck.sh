#!/usr/bin/env bash
# Windows-interop check: prove titles.json supplies usable title keys (rights-id) without title.keys.
set -u
T=D:/NSC_BUILDER/_t
sub(){ curl.exe -s -m20 -X POST http://127.0.0.1:54321/api/jobs -H "Content-Type: application/json" --data "{\"type\":\"$1\",\"inputs\":[\"$2\"],\"options\":$3}" | tr -d '\r' | python3 -c 'import sys,json;print(json.load(sys.stdin).get("id",""))'; }
fin(){ local j=$1; for k in $(seq 1 25); do r=$(curl.exe -s -m5 http://127.0.0.1:54321/api/jobs/$j | tr -d '\r' | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("status"),"|",(d.get("error") or "")[:55])' 2>/dev/null); case "$r" in Done*|Failed*) echo "$r"; return;; esac; sleep 2; done; echo TIMEOUT; }

# copy a Smash DLC (small) whose titleId is in the key+rightsId set
python3 - <<'PY'
import glob,shutil,os
for f in glob.glob('/mnt/e/**/*01006A800016F001*.nsz',recursive=True):
    try: shutil.copy(f,'/mnt/d/NSC_BUILDER/_t/dlc.nsz'); print('dlc',os.path.getsize('/mnt/d/NSC_BUILDER/_t/dlc.nsz'),'B'); break
    except Exception as e: print('copy fail',e)
else: print('dlc NOT FOUND')
PY
powershell.exe -NoProfile -Command "Start-Process -FilePath 'D:\NSC_BUILDER\_t\nscb.exe' -ArgumentList '--no-open' -WindowStyle Hidden" >/dev/null 2>&1
for i in $(seq 1 20); do [ "$(curl.exe -s -m2 -o /dev/null -w '%{http_code}' http://127.0.0.1:54321/api/settings)" = "200" ] && break; sleep 1; done

echo "[A] prod.keys + titles.json (no title.keys):"
curl.exe -s -m120 -X PUT http://127.0.0.1:54321/api/settings -H "Content-Type: application/json" --data '{"prodKeysPath":"D:/Tools/NSGManager_x64/prod.keys","titleKeysPath":"","titlesDbPath":"D:/Tools/titles.json"}' | tr -d '\r' | python3 -c 'import sys,json;d=json.load(sys.stdin);print("   keysLoaded",d["keysLoaded"],"titleKeysFromJson",d.get("titleKeysFromJson"))'
echo "   Verify(dlc) with json key : $(fin "$(sub Verify $T/dlc.nsz '{}')")"

echo "[B] titles.json disabled (prod.keys only, no title.keys):"
curl.exe -s -m120 -X PUT http://127.0.0.1:54321/api/settings -H "Content-Type: application/json" --data '{"prodKeysPath":"D:/Tools/NSGManager_x64/prod.keys","titleKeysPath":"","titlesDbPath":""}' >/dev/null
echo "   Verify(dlc) without json key: $(fin "$(sub Verify $T/dlc.nsz '{}')")"

powershell.exe -NoProfile -Command "Stop-Process -Name nscb -Force -ErrorAction SilentlyContinue" >/dev/null 2>&1
