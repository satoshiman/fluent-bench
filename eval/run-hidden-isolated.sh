#!/bin/bash
# Level 2 for isolated-clone runs (agentsmd + ad-hoc-iso). Appends to hidden-results.tsv.
set -u
BENCH="$(cd "$(dirname "$0")/.." && pwd)"
EVAL="$BENCH/eval"
OUT="$EVAL/hidden-results.tsv"

run_one() { # label abs_dir rel_test_path
  local label="$1" dir="$2" rel="$3"
  local name; name="$(basename "$rel")"
  cp "$EVAL/hidden/$name" "$dir/$rel" 2>/dev/null || { echo -e "$label\t$name\tCOPY\tmissing" >> "$OUT"; return; }
  local jf; jf="$(mktemp -t vitest-json).json"
  (cd "$dir" && HT_MIN_BACKOFF_MS="${HT_MIN_BACKOFF_MS:-0}" npx vitest run "$rel" --reporter=json --outputFile="$jf" >/dev/null 2>&1)
  python3 - "$jf" "$label" "$name" >> "$OUT" <<'PY'
import json,sys
jf,run,name=sys.argv[1:4]
try:
    d=json.load(open(jf))
    trs=d.get('testResults') or []
    found=False
    for tr in trs:
        for a in (tr.get('assertionResults') or []):
            found=True
            title=' > '.join(a.get('ancestorTitles',[])+[a.get('title','')])
            print(f"{run}\t{name}\t{title}\t{a.get('status','?')}")
    if not found:
        print(f"{run}\t{name}\tNO_TESTS\tfail")
except Exception as e:
    print(f"{run}\t{name}\tPARSE_ERROR\t{e}")
PY
  rm -f "$dir/$rel" "$jf"
}

HT_MIN_BACKOFF_MS=1400 run_one "T2/agentsmd" "$BENCH/runs-isolated/T2-agentsmd" server/translate/zz-hidden-t2.test.ts
run_one "T3/agentsmd" "$BENCH/runs-isolated/T3-agentsmd" server/stt/zz-hidden-t3.test.ts
run_one "T4/agentsmd" "$BENCH/runs-isolated/T4-agentsmd" web/src/lib/zz-hidden-t4.test.ts
HT_MIN_BACKOFF_MS=1400 run_one "T2/ad-hoc-iso" "$BENCH/runs-isolated/T2-ad-hoc" server/translate/zz-hidden-t2.test.ts
echo done
