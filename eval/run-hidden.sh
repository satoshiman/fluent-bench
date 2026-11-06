#!/bin/bash
# Level 2 runner: inject each hidden test into the right worktree subdir,
# run vitest on it, collect per-check results into eval/hidden-results.tsv.
set -u
BENCH="$(cd "$(dirname "$0")/.." && pwd)"
EVAL="$BENCH/eval"
OUT="$EVAL/hidden-results.tsv"
echo -e "run_dir\ttest_file\tcheck\tstatus" > "$OUT"

run_one() { # run_dir rel_test_path
  local dir="$BENCH/runs/$1" rel="$2"
  local name; name="$(basename "$rel")"
  cp "$EVAL/hidden/$name" "$dir/$rel" 2>/dev/null || { echo -e "$1\t$name\tCOPY\tmissing" >> "$OUT"; return; }
  local jf; jf="$(mktemp -t vitest-json).json"
  (cd "$dir" && HT_MIN_BACKOFF_MS="${HT_MIN_BACKOFF_MS:-0}" npx vitest run "$rel" --reporter=json --outputFile="$jf" >/dev/null 2>&1)
  python3 - "$jf" "$1" "$name" >> "$OUT" <<'PY'
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
            st=a.get('status','?')
            print(f"{run}\t{name}\t{title}\t{st}")
    if not found:
        print(f"{run}\t{name}\tNO_TESTS\tfail")
except Exception as e:
    print(f"{run}\t{name}\tPARSE_ERROR\t{e}")
PY
  rm -f "$dir/$rel" "$jf"
}

# matrix: run_dir -> test placement
run_one T1/ad-hoc             server/zz-hidden-t1.test.ts
run_one T1/doc-centric        server/zz-hidden-t1.test.ts
run_one V1/ad-hoc-vague       server/zz-hidden-t1.test.ts
run_one V1/doc-centric-vague  server/zz-hidden-t1.test.ts

HT_MIN_BACKOFF_MS=1400 run_one T2/ad-hoc   server/translate/zz-hidden-t2.test.ts
HT_MIN_BACKOFF_MS=1400 run_one T2/doc-centric server/translate/zz-hidden-t2.test.ts
HT_MIN_BACKOFF_MS=0    run_one V2/ad-hoc-vague  server/translate/zz-hidden-t2.test.ts
HT_MIN_BACKOFF_MS=0    run_one V2/doc-centric-vague server/translate/zz-hidden-t2.test.ts

run_one T3/ad-hoc             server/stt/zz-hidden-t3.test.ts
run_one T3/doc-centric        server/stt/zz-hidden-t3.test.ts

run_one T4/ad-hoc             web/src/lib/zz-hidden-t4.test.ts
run_one T4/doc-centric        web/src/lib/zz-hidden-t4.test.ts
run_one V3/ad-hoc-vague       web/src/lib/zz-hidden-t4.test.ts
run_one V3/doc-centric-vague  web/src/lib/zz-hidden-t4.test.ts

run_one T5/ad-hoc             web/src/lib/zz-hidden-t5.test.ts
run_one T5/doc-centric        web/src/lib/zz-hidden-t5.test.ts

run_one T6/ad-hoc             server/session/zz-hidden-t6.test.ts
run_one T6/doc-centric        server/session/zz-hidden-t6.test.ts

run_one chain/work            server/audio/zz-hidden-c.test.ts
echo "=== done ==="; column -t -s$'\t' "$OUT" | head -100
