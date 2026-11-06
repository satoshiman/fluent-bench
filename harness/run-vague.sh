#!/bin/bash
# Vague-prompt tier: 3 tasks x 2 arms. ad-hoc=1 session, doc-centric=split 3 sessions.
set -u
BENCH="$(cd "$(dirname "$0")" && pwd)"

adhoc() { # task prompt
  local t=$1 p=$2 dir=
  dir="$BENCH/runs/$t/ad-hoc-vague"
  mkdir -p "$BENCH/runs/$t"
  "$BENCH/new-run.sh" "$t" ad-hoc >/dev/null 2>&1 || true
  # move auto-named dir to -vague suffix
  rm -rf "$dir"; mv "$BENCH/runs/$t/ad-hoc" "$dir" 2>/dev/null || true
  echo ">>> $t ad-hoc-vague $(date +%H:%M:%S)"
  date +%s > "$dir/.start_time"
  (cd "$dir" && env -u ACP_BACKEND devin -p --respect-workspace-trust false \
     --permission-mode dangerous --export transcript.json \
     -- "$(cat "$BENCH/prompts/$p")" > agent-output.log 2>&1)
  date +%s > "$dir/.end_time"
  (cd "$dir" && git add -A -- server web scripts 2>/dev/null; \
   git -c user.name=bench -c user.email=bench@local commit -qm "bench: $t vague output" 2>/dev/null; \
   git format-patch -1 --stdout > "$BENCH/runs/$t-ad-hoc-vague.patch" 2>/dev/null; true)
  echo "<<< $t ad-hoc-vague done"
}

doccentric() {
  local t=$1 p=$2 dir=
  dir="$BENCH/runs/$t/doc-centric-vague"
  mkdir -p "$BENCH/runs/$t"
  "$BENCH/new-run.sh" "$t" doc-centric >/dev/null 2>&1 || true
  rm -rf "$dir"; mv "$BENCH/runs/$t/doc-centric" "$dir" 2>/dev/null || true
  echo ">>> $t doc-centric-vague(split) $(date +%H:%M:%S)"
  date +%s > "$dir/.start_time"
  "$BENCH/run-doccentric.sh" "$t" "$dir" "$p"
  date +%s > "$dir/.end_time"
  echo "<<< $t doc-centric-vague done"
}

# V1=T1-vtt, V2=T2-retry, V3=T4-search ; random order per pair
if (( RANDOM % 2 )); then adhoc V1 V1-vtt-export.md; doccentric V1 V1-vtt-export.md;
else doccentric V1 V1-vtt-export.md; adhoc V1 V1-vtt-export.md; fi
if (( RANDOM % 2 )); then adhoc V2 V2-translation-retry.md; doccentric V2 V2-translation-retry.md;
else doccentric V2 V2-translation-retry.md; adhoc V2 V2-translation-retry.md; fi
if (( RANDOM % 2 )); then adhoc V3 V3-sessions-search.md; doccentric V3 V3-sessions-search.md;
else doccentric V3 V3-sessions-search.md; adhoc V3 V3-sessions-search.md; fi
echo "=== VAGUE TIER DONE ==="
