#!/bin/bash
# Windows interop functional battery: exercises every operation + facets against real files.
B='http://127.0.0.1:54321'
T='D:/NSC_BUILDER/_t'
PY() { python3 -c "$1"; }

runjob() { # $1=TYPE $2=inputsJSON $3=optionsJSON
  local jid st out err r
  jid=$(curl.exe -s -m30 -X POST "$B/api/jobs" -H 'Content-Type: application/json' \
    --data "{\"type\":\"$1\",\"inputs\":$2,\"options\":${3:-{}}}" 2>/dev/null | tr -d '\r' | PY 'import sys,json;print(json.load(sys.stdin).get("id",""))')
  if [ -z "$jid" ]; then printf '  %-16s %-7s | %s\n' "$1" "SUBMIT-FAIL" ""; RET_OUT=""; return; fi
  for k in $(seq 1 90); do
    r=$(curl.exe -s -m8 "$B/api/jobs/$jid" 2>/dev/null | tr -d '\r' | PY 'import sys,json;d=json.load(sys.stdin);sys.stdout.write((d.get("status") or "?")+"\x1f"+(d.get("outputPath") or "")+"\x1f"+((d.get("error") or "").replace(chr(10)," ")[:90]))')
    st=${r%%$'\x1f'*}; rest=${r#*$'\x1f'}; out=${rest%%$'\x1f'*}; err=${rest#*$'\x1f'}
    st=$(echo "$st" | tr -d ' '); out=$(echo "$out" | sed 's/^ *//;s/ *$//'); out=${out//\\//}   # forward slashes for JSON reuse
    case "$st" in Done|Failed|Cancelled) break;; esac
    sleep 1
  done
  printf '  %-16s %-7s | out=%s | err=%s\n' "$1" "$st" "${out:0:64}" "$err"
  RET_OUT="$out"
}

facets() { # $1=path  -> hit info + npdm + verify endpoints
  local P=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" "$1")
  local nm=$(curl.exe -s -m60 "$B/api/info?path=$P" 2>/dev/null | tr -d '\r' | PY 'import sys,json;d=json.load(sys.stdin);print(d.get("titleName"),"/",d.get("titleType"),"/",d.get("titleId"))' 2>/dev/null)
  local np=$(curl.exe -s -m120 "$B/api/npdm?path=$P" 2>/dev/null | tr -d '\r' | PY 'import sys,json;d=json.load(sys.stdin);print(d.get("processCategory") or d.get("error"))' 2>/dev/null)
  local vf=$(curl.exe -s -m120 "$B/api/verify?path=$P" 2>/dev/null | tr -d '\r' | PY 'import sys,json;d=json.load(sys.stdin);print("ok" if d.get("ok") else ("FAIL:"+str(len(d.get("failures",[])))),"checked="+str(d.get("checked"))+"/"+str(d.get("total")))' 2>/dev/null)
  printf '  INFO/verify %s\n    info: %s\n    npdm: %s\n    verify: %s\n' "$1" "$nm" "$np" "$vf"
}

echo "== keys =="
curl.exe -s -m5 -X PUT "$B/api/settings" -H 'Content-Type: application/json' --data "{\"prodKeysPath\":\"D:/Tools/NSGManager_x64/prod.keys\",\"titleKeysPath\":\"D:/Tools/title.keys\",\"outputDir\":\"$T/out\"}" 2>/dev/null >/dev/null
curl.exe -s -m5 "$B/api/settings" 2>/dev/null | tr -d '\r' | PY 'import sys,json;d=json.load(sys.stdin);print("  keysLoaded",d.get("keysLoaded"),"titleKeysFromJson",d.get("titleKeysFromJson"),"err",d.get("keysError"))'
mkdir -p /mnt/d/NSC_BUILDER/_t/out 2>/dev/null
NSZ="$T/leaf.nsp"; NSZ="$T/leaf.nsz"; XCI=""; XCZ=""

echo "== facets on leafgreen APP (base .nsz) =="
facets "$T/leaf.nsz"

echo "== convert / pack chain =="
runjob ConvertNspToXci "[\"$T/leaf.nsz\"]"; XCI="$RET_OUT"
runjob ConvertXciToNsp "[\"$XCI\"]"
runjob CompressNsz "[\"$T/leaf.nsz\"]"
runjob CompressXcz "[\"$XCI\"]"; XCZ="$RET_OUT"
runjob PackXci "[\"$T/pack\"]"

echo "== content ops =="
runjob DecompressNsz "[\"$T/leaf.nsz\"]"
runjob Extract "[\"$T/leaf.nsz\"]"
runjob SplitTitles "[\"$T/leaf.nsz\"]"
runjob GenXml "[\"$T/leaf.nsz\"]"
runjob Verify "[\"$T/leaf.nsz\"]"

echo "== xci ops =="
runjob DecompressXcz "[\"$XCZ\"]"
runjob TrimXci "[\"$XCI\"]"
runjob SuperTrimXci "[\"$XCI\"]"
runjob EraseDeltas "[\"$XCI\"]"

echo "== patch/modify (may fail if title key absent — reported honestly) =="
runjob PatchRsv "[\"$NSZ\"]" "{\"rsv\":\"1200\"}"
runjob PatchKeygen "[\"$NSZ\"]" "{\"kg\":\"3\"}"
runjob SetCnmtTitleId "[\"$NSZ\"]" "{\"titleid\":\"0100000000000000\"}"
runjob SetCnmtVersion "[\"$NSZ\"]" "{\"version\":\"1\"}"
runjob SetCgame "[\"$NSZ\"]"
runjob SetEshop "[\"$NSZ\"]"
runjob RelinkAccount "[\"$NSZ\"]" "{\"account\":\"0000000000000000\"}"
runjob RemoveTitleKey "[\"$NSZ\"]"
runjob UpdBase "[\"$T/leaf.nsz\",\"$T/upd.nsz\"]"

echo "== fat32 / join =="
runjob SplitFat32 "[\"$XCI\"]"
runjob MergeFat32 "[\"$XCI.00\"]"
runjob JoinFile "[\"$XCI.00\",\"$XCI.01\"]"

echo "== database / rename (folder) =="
runjob Database "[\"$T/pack\"]" "{\"format\":\"json\"}"
runjob Rename "[\"$T/pack\"]"

echo "== artifacts on disk =="
ls -1 /mnt/d/NSC_BUILDER/_t/*.xci /mnt/d/NSC_BUILDER/_t/*.nsp /mnt/d/NSC_BUILDER/_t/*.nsz /mnt/d/NSC_BUILDER/_t/*.xcz /mnt/d/NSC_BUILDER/_t/*.nca 2>/dev/null | sed 's#/mnt/d#D:#'
echo "--- pack folder (pack naming) ---"; ls -1 /mnt/d/NSC_BUILDER/_t/pack/ 2>/dev/null | sed 's/^/  pack: /'
