#!/bin/bash
# Regenerate results.csv from per-run transcripts + timing files.
set -u
BENCH="$(cd "$(dirname "$0")" && pwd)"
CSV="$BENCH/results.csv"
echo "task,arm,wall_s,prompt_tok,completion_tok,cached_tok,model" > "$CSV"
emit() { # task arm dir transcript
  local task=$1 arm=$2 dir=$3 tr=$4
  [[ -f "$dir/.start_time" && -f "$dir/.end_time" && -f "$tr" ]] || return 0
  python3 - "$tr" "$task" "$arm" "$dir" >> "$CSV" <<'PY'
import json, os, sys
tr, task, arm, d = sys.argv[1:5]
j = json.load(open(tr)); fm = j.get('final_metrics', {})
wall = int(open(d+'/.end_time').read()) - int(open(d+'/.start_time').read())
print(f"{task},{arm},{wall},{fm.get('total_prompt_tokens')},{fm.get('total_completion_tokens')},{fm.get('total_cached_tokens')},{j.get('agent',{}).get('model_name')}")
PY
}
for t in T1 T2 T3 T4 T5 T6; do
  for a in ad-hoc doc-centric; do
    emit "$t" "$a" "$BENCH/runs/$t/$a" "$BENCH/runs/$t/$a/transcript.json"
  done
done
for i in 1 2 3; do
  emit "C$i" "doc-centric" "$BENCH/runs/chain/work" "$BENCH/runs/chain/work/transcript-C$i.json"
done
for t in T2 T3 T4; do
  emit "$t" "agentsmd" "$BENCH/runs-isolated/$t-agentsmd" "$BENCH/runs-isolated/$t-agentsmd/transcript.json"
done
cat "$CSV"
