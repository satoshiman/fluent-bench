#!/bin/bash
# Create a bench run: git worktree at bench-base + shared node_modules.
# Usage: ./new-run.sh <task-id> <arm>     e.g. ./new-run.sh T1 ad-hoc
set -euo pipefail

TASK="$1"; ARM="$2"           # arm: doc-centric | ad-hoc
REPO="$(cd "$(dirname "$0")" && pwd)/repo"
RUNS="$(cd "$(dirname "$0")" && pwd)/runs"
DEST="$RUNS/$TASK/$ARM"
BRANCH="bench/$TASK-$ARM"

if [[ "$ARM" != "doc-centric" && "$ARM" != "ad-hoc" ]]; then
  echo "arm must be doc-centric or ad-hoc" >&2; exit 1
fi
if [[ -e "$DEST" ]]; then
  echo "run dir already exists: $DEST" >&2; exit 1
fi

cd "$REPO"
git worktree add -b "$BRANCH" "$DEST" bench-base >/dev/null
mkdir -p "$DEST"

# share dependencies instead of reinstalling
ln -s "$REPO/node_modules" "$DEST/node_modules"
ln -s "$REPO/web/node_modules" "$DEST/web/node_modules"

if [[ "$ARM" == "ad-hoc" ]]; then
  # strip the context hierarchy so the agent truly has no docs
  rm -rf "$DEST/CONTEXTS" "$DEST/AGENTS.md"
  # drop the workflow section from README (keep features/quickstart)
  python3 - "$DEST/README.md" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r'## Built with the Context as an Asset workflow.*', '', s, flags=re.S)
open(p, 'w').write(s.rstrip() + '\n')
PY
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
