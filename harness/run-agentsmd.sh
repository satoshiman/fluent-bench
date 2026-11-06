#!/bin/bash
# Task 006 cheap scope: agentsmd arm (AGENTS.md only, no CONTEXTS) on T2/T3/T4.
# Runs live in runs-isolated/<T>-agentsmd as standalone clones (see new-run.sh).
set -u
BENCH="$(cd "$(dirname "$0")" && pwd)"

agentsmd() { # task prompt
  local t=$1 p=$2
  local dir="$BENCH/runs-isolated/$t-agentsmd"
  "$BENCH/new-run.sh" "$t" agentsmd
  echo ">>> $t agentsmd $(date +%H:%M:%S)"
  date +%s > "$dir/.start_time"
  (cd "$dir" && env -u ACP_BACKEND devin -p --model swe-2-high \
     --respect-workspace-trust false --permission-mode dangerous \
     --export transcript.json \
     -- "$(cat "$BENCH/prompts/$p")" > agent-output.log 2>&1)
  date +%s > "$dir/.end_time"
  (cd "$dir" && git add -A -- server web scripts CONTEXTS 2>/dev/null; \
   git -c user.name=bench -c user.email=bench@local commit -qm "bench: $t output" 2>/dev/null; \
   git format-patch --root HEAD --stdout > "$BENCH/runs/$t-agentsmd.patch" 2>/dev/null; true)
  echo "<<< $t agentsmd done $(date +%H:%M:%S)"
}

agentsmd T2 T2-translation-retry.md
agentsmd T3 T3-deepgram-reconnect.md
agentsmd T4 T4-sessions-search.md
echo "=== ALL DONE ==="
