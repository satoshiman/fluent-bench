#!/bin/bash
# Create a bench run: git worktree at bench-base + shared node_modules.
# Usage: ./new-run.sh <task-id> <arm>     e.g. ./new-run.sh T1 ad-hoc
#
# arm agentsmd (and ad-hoc with ISOLATED=1) is different on purpose: a
# STANDALONE git clone of the squashed snapshot placed under runs-isolated/.
# A normal worktree shares the repo's refs (bench-base), sits next to
# doc-centric siblings, and symlinks node_modules into repo/ - all of which
# leaked context in earlier runs and invalidated them.
set -euo pipefail

TASK="$1"; ARM="$2"           # arm: doc-centric | ad-hoc | agentsmd
BENCH="$(cd "$(dirname "$0")" && pwd)"
REPO="$BENCH/repo"
RUNS="$BENCH/runs"
DEST="$RUNS/$TASK/$ARM"
BRANCH="bench/$TASK-$ARM"

if [[ "$ARM" == "agentsmd" || ( "$ARM" == "ad-hoc" && "${ISOLATED:-0}" == "1" ) ]]; then
  DEST="$BENCH/runs-isolated/$TASK-$ARM"
fi

if [[ "$ARM" != "doc-centric" && "$ARM" != "ad-hoc" && "$ARM" != "agentsmd" ]]; then
  echo "arm must be doc-centric, ad-hoc or agentsmd" >&2; exit 1
fi
if [[ -e "$DEST" ]]; then
  echo "run dir already exists: $DEST" >&2; exit 1
fi

strip_readme() {
  python3 - "$1/README.md" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r'## Built with the Context as an Asset workflow.*', '', s, flags=re.S)
open(p, 'w').write(s.rstrip() + '\n')
PY
}

cd "$REPO"

if [[ "$ARM" == "agentsmd" || ( "$ARM" == "ad-hoc" && "${ISOLATED:-0}" == "1" ) ]]; then
  # build the stripped snapshot in a scratch worktree, then clone it so the
  # run dir carries no refs, no remote, and no doc-bearing siblings.
  # node_modules is copied, not symlinked: a symlink resolves into repo/ and
  # Devin then injects repo/AGENTS.md as an always-on rule mid-run (seen in
  # the contaminated T2/ad-hoc transcript, step 17).
  SCRATCH="$(mktemp -d)/wt"
  git worktree add --detach "$SCRATCH" bench-base >/dev/null
  rm -rf "$SCRATCH/CONTEXTS"
  [[ "$ARM" == "ad-hoc" ]] && rm -f "$SCRATCH/AGENTS.md"   # agentsmd keeps it
  strip_readme "$SCRATCH"
  (cd "$SCRATCH" && git checkout --orphan "snap/$TASK-$ARM" >/dev/null 2>&1 \
     && git add -A && git commit -qm "snapshot" >/dev/null)
  mkdir -p "$BENCH/runs-isolated"
  git clone --quiet --single-branch --branch "snap/$TASK-$ARM" "$REPO" "$DEST"
  git -C "$DEST" remote remove origin        # no path back to repo refs
  git -C "$DEST" branch -m "snap/$TASK-$ARM" main
  git worktree remove --force "$SCRATCH"
  git branch -D "snap/$TASK-$ARM" >/dev/null 2>&1 || true
  # real copies, not symlinks: a symlink to repo/node_modules leaks the path
  cp -Rc "$REPO/node_modules" "$DEST/node_modules"
  cp -Rc "$REPO/web/node_modules" "$DEST/web/node_modules"
  echo "run ready: $DEST"
  echo "base commit: $(git -C "$DEST" rev-parse --short HEAD)"
  exit 0
fi

git worktree add -b "$BRANCH" "$DEST" bench-base >/dev/null
mkdir -p "$DEST"

# share dependencies instead of reinstalling
ln -s "$REPO/node_modules" "$DEST/node_modules"
ln -s "$REPO/web/node_modules" "$DEST/web/node_modules"

if [[ "$ARM" == "ad-hoc" ]]; then
  # strip the context hierarchy so the agent truly has no docs
  rm -rf "$DEST/CONTEXTS" "$DEST/AGENTS.md"
  # drop the workflow section from README (keep features/quickstart)
  strip_readme "$DEST"
  # squash history: commit messages reference ADRs/BDRs and would leak
  # decision context to the ad-hoc agent
  cd "$DEST"
  git checkout --orphan "adhoc-squash" >/dev/null 2>&1
  git add -A
  git commit -qm "snapshot" >/dev/null
  git branch -D "$BRANCH" >/dev/null 2>&1 || true
  git branch -m "adhoc-squash" "$BRANCH"
fi

echo "run ready: $DEST"
echo "base commit: $(git -C "$DEST" rev-parse --short HEAD~0 2>/dev/null || true)"
