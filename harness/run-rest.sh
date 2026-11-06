#!/bin/bash
# Remaining bench: doc-centric = split sessions (plan/review/impl), ad-hoc = single.
set -u
BENCH="$(cd "$(dirname "$0")" && pwd)"

adhoc() { # task prompt
  local t=$1 p=$2 dir="$BENCH/runs/$t/ad-hoc"
  "$BENCH/new-run.sh" "$t" ad-hoc
  echo ">>> $t ad-hoc $(date +%H:%M:%S)"
  date +%s > "$dir/.start_time"
  (cd "$dir" && env -u ACP_BACKEND devin -p --respect-workspace-trust false \
     --permission-mode dangerous --export transcript.json \
     -- "$(cat "$BENCH/prompts/$p")" > agent-output.log 2>&1)
  date +%s > "$dir/.end_time"
  (cd "$dir" && git add -A -- server web scripts 2>/dev/null; \
   git -c user.name=bench -c user.email=bench@local commit -qm "bench: $t output" 2>/dev/null; \
   git format-patch -1 --stdout > "$BENCH/runs/$t-ad-hoc.patch" 2>/dev/null; true)
  echo "<<< $t ad-hoc done"
}

doccentric() { # task prompt dir(optional, default runs/T/doc-centric)
  local t=$1 p=$2 dir=${3:-}
  if [[ -z "$dir" ]]; then dir="$BENCH/runs/$t/doc-centric"; fi
  if [[ ! -d "$dir" ]]; then "$BENCH/new-run.sh" "$t" doc-centric; fi
  echo ">>> $t doc-centric(split) $(date +%H:%M:%S)"
  date +%s > "$dir/.start_time"
  "$BENCH/run-doccentric.sh" "$t" "$dir" "$p"
  date +%s > "$dir/.end_time"
  echo "<<< $t doc-centric done"
}

P_T1=T1-vtt-export.md;    P_T2=T2-translation-retry.md; P_T3=T3-deepgram-reconnect.md
P_T4=T4-sessions-search.md; P_T5=T5-playback-speed.md;  P_T6=T6-merge-segments.md

# redo T1/T2 doc-centric with split protocol (v1 single-session preserved as .patch)
doccentric T1 $P_T1
doccentric T2 $P_T2
# T3-T6 pairs: random order, doc split / ad-hoc single
for t in T3 T4 T5 T6; do
  case $t in T3) P=$P_T3;; T4) P=$P_T4;; T5) P=$P_T5;; T6) P=$P_T6;; esac
  if (( RANDOM % 2 )); then doccentric "$t" "$P"; adhoc "$t" "$P";
  else adhoc "$t" "$P"; doccentric "$t" "$P"; fi
done
# chain C1-C3: shared doc-centric worktree, each task = split sessions
CH="$BENCH/runs/chain/work"
(cd "$BENCH/repo" && git worktree add -b bench/chain "$CH" bench-base && \
 ln -s "$BENCH/repo/node_modules" "$CH/node_modules" && \
 ln -s "$BENCH/repo/web/node_modules" "$CH/web/node_modules")
i=0
for c in C1-recording-pause.md C2-recording-cap.md C3-recording-status-ui.md; do
  i=$((i+1)); doccentric "C$i" "$c" "$CH"
done
echo "=== ALL DONE ==="
