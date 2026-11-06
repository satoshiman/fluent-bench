#!/bin/bash
# Split-session doc-centric run: plan -> review -> implement (3 fresh sessions).
# Usage: run-doccentric.sh <task> <dir> <prompt-file>
set -u
BENCH="$(cd "$(dirname "$0")" && pwd)"
TASK=$1; DIR=$2; PROMPT=$3
run_phase() { # phase-name prompt-text
  (cd "$DIR" && env -u ACP_BACKEND devin -p --respect-workspace-trust false \
     --permission-mode dangerous --export "transcript-$1.json" \
     -- "$2" >> agent-output.log 2>&1)
  echo "[$(date +%H:%M:%S)] $TASK $1 done"
}
SPEC=$(cat "$BENCH/prompts/$PROMPT")
run_phase plan "$SPEC

IMPORTANT: work per this repo's AGENTS.md conventions. Only DRAFT the implementation plan in CONTEXTS/03-implement-plan/ (new PLAN id). Skip clarifications and requirement breakdown: record assumptions in the plan's Risks/notes. Do NOT create new BDRs/ADRs. Do NOT implement anything. Commit only the plan document."
run_phase review "Run ONE verification pass on the newest PLAN in CONTEXTS/03-implement-plan/ per AGENTS.md workflow: re-check it against BDRs, ADRs, and the codebase; patch divergences in the plan; update review_count and patch frontmatter. Do NOT implement. Commit only plan changes."
run_phase impl "Implement the newest PLAN in CONTEXTS/03-implement-plan/ exactly per its scope and DoD. Commit, tick DoD items, set status: implemented, and log via CONTEXTS/04-logs/event.py."
