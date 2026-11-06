#!/bin/bash
# Fetch the fluent base repository at the pinned bench commit.
set -euo pipefail
BASE_COMMIT=81dd3986324aa885de1d6d89faf347d6a10aed1b
HERE="$(cd "$(dirname "$0")/.." && pwd)"
if [ ! -d "$HERE/repo" ]; then
  git clone https://github.com/satoshiman/fluent "$HERE/repo"
fi
cd "$HERE/repo"
git fetch --tags -q
git checkout -B bench-base "$BASE_COMMIT"
npm install
(cd web && npm install)
echo "repo ready at bench-base ($BASE_COMMIT)"
