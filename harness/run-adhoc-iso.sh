#!/bin/bash
# Rerun T2 ad-hoc isolated: worktree run was contaminated (repo/AGENTS.md
# injected as always-on rule via node_modules symlink -> step 17 transcript).
set -u
BENCH="$(cd "$(dirname "$0")" && pwd)"
T=T2; P=T2-translation-retry.md
DIR="$BENCH/runs-isolated/$T-ad-hoc"

ISOLATED=1 "$BENCH/new-run.sh" "$T" ad-hoc
echo ">>> $T ad-hoc isolated $(date +%H:%M:%S)"
date +%s > "$DIR/.start_time"
(cd "$DIR" && env -u ACP_BACKEND devin -p --model swe-2-high \
   --respect-workspace-trust false --permission-mode dangerous \
   --export transcript.json \
   -- "$(cat "$BENCH/prompts/$P")" > agent-output.log 2>&1)
date +%s > "$DIR/.end_time"
(cd "$DIR" && git add -A -- server web scripts 2>/dev/null; \
 git -c user.name=bench -c user.email=bench@local commit -qm "bench: $T output" 2>/dev/null; \
 git format-patch --root HEAD --stdout > "$BENCH/runs/$T-ad-hoc-isolated.patch" 2>/dev/null; true)
echo "<<< $T ad-hoc isolated done $(date +%H:%M:%S)"
