#!/bin/bash
B='http://127.0.0.1:54321'; BF='/mnt/d/NSC_BUILDER/_t2/body.json'; BW='D:/NSC_BUILDER/_t2/body.json'
OUT='D:/NSC_BUILDER/_t2'; mkdir -p /mnt/d/NSC_BUILDER/_t2
BASE='D:/111/OBAKEIDORO 2 Chase & Seek [010044D027C72000][v0][Base].nsz'
UPD='D:/111/OBAKEIDORO 2 Chase & Seek v2.0.21[010044D027C72800][v262144][UPD].nsz'
facets(){ P=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" "$1")
  curl.exe -s -m90 "$B/api/info?path=$P" 2>/dev/null | tr -d '\r' | python3 -c 'import sys,json;d=json.load(sys.stdin);print("    info:",d.get("titleName"),"/",d.get("titleType"),"/",d.get("titleId"),"ver",d.get("titleVersion"),"key?",d.get("titleKeyAvailable"))'
  curl.exe -s -m180 "$B/api/npdm?path=$P" 2>/dev/null | tr -d '\r' | python3 -c 'import sys,json;d=json.load(sys.stdin);print("    npdm:",d.get("processCategory") or d.get("error"),"| svcs",len(d.get("services",[])))'
  curl.exe -s -m180 "$B/api/verify?path=$P" 2>/dev/null | tr -d '\r' | python3 -c 'import sys,json;d=json.load(sys.stdin);print("    verify:","ok" if d.get("ok") else "FAIL("+str(len(d.get("failures",[])))+")","checked",str(d.get("checked"))+"/"+str(d.get("total")))'; }
run1(){ python3 -c "import json,sys;open(sys.argv[1],'w').write(json.dumps({'type':sys.argv[2],'inputs':json.loads(sys.argv[3]),'options':json.loads(sys.argv[4])}))" "$BF" "$1" "$2" "$3"
  jid=$(curl.exe -s -m60 -X POST "$B/api/jobs" -H 'Content-Type: application/json' --data @"$BW" 2>/dev/null | tr -d '\r' | python3 -c 'import sys,json;print(json.load(sys.stdin).get("id",""))' 2>/dev/null)
  [ -z "$jid" ] && { printf '  %-16s SUBMIT-FAIL\n' "$1"; RET_OUT=""; return; }
  for k in $(seq 1 200); do r=$(curl.exe -s -m8 "$B/api/jobs/$jid" 2>/dev/null | tr -d '\r' | python3 -c 'import sys,json;d=json.load(sys.stdin);sys.stdout.write((d.get("status")or"?")+"\x1f"+(d.get("outputPath")or"")+"\x1f"+((d.get("error")or"")[:70]))'); st=${r%%$'\x1f'*}; o=${r#*$'\x1f'}; out=${o%%$'\x1f'*}; err=${o#*$'\x1f'}; out=$(echo "$out"|sed 's#\\#/#g'); case "$st" in Done|Failed|Cancelled) break;; esac; sleep 1; done
  printf '  %-16s %-7s | %s | %s\n' "$1" "$st" "${out:0:60}" "$err"; RET_OUT="$out"; }
echo "== facets on OBAKEIDORO base (key present) =="; facets "$BASE"
echo "== NSP round-trip + key ops on OBAKEIDORO =="
run1 DecompressNsz "[\"$BASE\"]" '{}'; NSP="$RET_OUT"
run1 CompressNsz "[\"$NSP\"]" '{}'
run1 PatchKeygen "[\"$NSP\"]" '{"keygen":"4"}'
run1 SetCgame "[\"$BASE\"]" '{}'
run1 RemoveTitleKey "[\"$BASE\"]" '{}'
run1 UpdBase "[\"$BASE\",\"$UPD\"]" '{}'
run1 PackXci "[\"$BASE\",\"$UPD\"]" '{}'
echo "== xci + content ops on OBAKEIDORO =="
run1 ConvertNspToXci "[\"$BASE\"]" '{}'; XC="$RET_OUT"
run1 Extract "[\"$BASE\"]" '{}'
run1 SplitTitles "[\"$BASE\"]" '{}'
run1 GenXml "[\"$BASE\"]" '{}'
run1 TrimXci "[\"$XC\"]" '{}'
run1 SplitFat32 "[\"$XC\"]" '{}'
run1 Database "[\"D:/111\"]" '{"format":"json"}'
