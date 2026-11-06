#!/bin/bash
# Level 1: re-run npm test + typecheck in every run worktree.
set -u
BENCH="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$BENCH/eval/level1.tsv"
echo -e "run_dir\ttest_pass\ttest_fail\ttypecheck\twall_s" > "$OUT"
for d in "$BENCH"/runs/T*/*/ "$BENCH"/runs/V*/*/ "$BENCH"/runs/chain/work/; do
  [ -d "$d" ] || continue
  name="${d#$BENCH/runs/}"; name="${name%/}"
  start=$(date +%s)
  testout=$(cd "$d" && npm test 2>&1 | tail -20)
  pass=$(echo "$testout" | grep -oE '[0-9]+ passed' | tail -1 | grep -oE '[0-9]+')
  fail=$(echo "$testout" | grep -oE '[0-9]+ failed' | tail -1 | grep -oE '[0-9]+')
  [ -z "$pass" ] && pass=0; [ -z "$fail" ] && fail=0
  tc=$(cd "$d" && npm run typecheck >/dev/null 2>&1 && echo ok || echo FAIL)
  end=$(date +%s)
  echo -e "$name\t$pass\t$fail\t$tc\t$((end-start))" | tee -a "$OUT"
done
