#!/bin/bash
# Drive remaining bench runs: pairs T2-T6 (random arm order) + chain C1-C3.
set -u
BENCH="$(cd "$(dirname "$0")" && pwd)"
CSV="$BENCH/results.csv"
echo "task,arm,run_order,wall_s,prompt_tok,completion_tok,cached_tok,model,tests,test_status,typecheck,outcome" > "$CSV"

run_task() { # task arm order rundir promptfile
  local task=$1 arm=$2 order=$3 dir=$4 prompt=$5
  echo ">>> $task/$arm (order $order) start $(date +%H:%M:%S)"
  date +%s > "$dir/.start_time"
  (cd "$dir" && env -u ACP_BACKEND devin -p --respect-workspace-trust false \
      --permission-mode dangerous --export transcript.json \
      -- "$(cat "$BENCH/prompts/$prompt")" > agent-output.log 2>&1)
  date +%s > "$dir/.end_time"
  # commit leftover diff (doc-centric arm self-commits via event.py workflow)
  (cd "$dir" && git add -A -- server web scripts CONTEXTS package.json 2>/dev/null; \
   git -c user.name=bench -c user.email=bench@local commit -qm "bench: $task output" 2>/dev/null; \
   git format-patch -1 --stdout > "$BENCH/runs/$task-$arm.patch" 2>/dev/null; true)
  # verify endpoint
  local tests=$(cd "$dir" && npm test 2>&1 | grep -oE "Tests +[0-9]+ passed|[0-9]+ failed" | head -1)
  local tstatus="green"; cd "$dir" && npm test >/dev/null 2>&1 || tstatus="red"; cd "$BENCH"
  local tcheck="ok"; (cd "$dir" && npm run typecheck >/dev/null 2>&1) || tcheck="fail"
  local wall=$(( $(cat "$dir/.end_time") - $(cat "$dir/.start_time") ))
  python3 - "$dir/transcript.json" "$task" "$arm" "$order" "$wall" "$tests" "$tstatus" "$tcheck" >> "$CSV" <<'PY'
import json, sys
f, task, arm, order, wall, tests, tstatus, tcheck = sys.argv[1:8]
d = json.load(open(f)); fm = d.get('final_metrics', {})
print(f"{task},{arm},{order},{wall},{fm.get('total_prompt_tokens')},{fm.get('total_completion_tokens')},{fm.get('total_cached_tokens')},{d.get('agent',{}).get('model_name')},\"{tests}\",{tstatus},{tcheck},merged")
PY
  echo "<<< $task/$arm done wall=${wall}s"
}

# pairs T2-T6: random arm order per pair
for t in T2 T3 T4 T5 T6; do
  case $t in
    T2) P=T2-translation-retry.md;; T3) P=T3-deepgram-reconnect.md;;
    T4) P=T4-sessions-search.md;; T5) P=T5-playback-speed.md;;
    T6) P=T6-merge-segments.md;;
  esac
  if (( RANDOM % 2 )); then arms="doc-centric ad-hoc"; else arms="ad-hoc doc-centric"; fi
  o=0
  for a in $arms; do
    o=$((o+1))
    "$BENCH/new-run.sh" "$t" "$a"
    run_task "$t" "$a" "$o" "$BENCH/runs/$t/$a" "$P"
  done
done

# chain C1-C3: doc-centric, ONE shared worktree so docs accumulate
CHAIN="$BENCH/runs/chain/work"
(cd "$BENCH/repo" && git worktree add -b bench/chain "$CHAIN" bench-base && \
 ln -s "$BENCH/repo/node_modules" "$CHAIN/node_modules" && \
 ln -s "$BENCH/repo/web/node_modules" "$CHAIN/web/node_modules")
i=0
for c in C1-recording-pause.md C2-recording-cap.md C3-recording-status-ui.md; do
  i=$((i+1)); tid="C$i"
  # preserve per-task transcript before next run overwrites it
  run_task "$tid" "doc-centric" "$i" "$CHAIN" "$c"
  cp "$CHAIN/transcript.json" "$CHAIN/transcript-$tid.json" 2>/dev/null || true
done
echo "=== ALL RUNS DONE ==="
