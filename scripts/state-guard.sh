#!/usr/bin/env bash
# Fail when non-doc paths change without a STATE.md change.
# Escape hatch: every commit subject starts with chore:, deps:, or is a bot bump.
set -euo pipefail
base=${1:-origin/main}
changed=$(git diff --name-only "$base"...HEAD)
[ -z "$changed" ] && { echo "state-guard: no changes vs $base"; exit 0; }
if echo "$changed" | grep -qx 'STATE.md'; then echo "state-guard: STATE.md updated"; exit 0; fi
code=$(echo "$changed" | grep -Ev '^(LESSONS\.md|ROADMAP\.md|README\.md|docs/)' || true)
[ -z "$code" ] && { echo "state-guard: docs-only change"; exit 0; }
subjects=$(git log --no-merges --format=%s "$base"..HEAD)
# A merges-only range has no subjects to vouch for it, so it gets no escape hatch
# (grep on empty input exits 1, which used to read as "every subject matched").
if [ -z "$subjects" ] || echo "$subjects" | grep -Evq '^(chore|deps)(\(.+\))?!?:|^Update claudeglance to '; then
  echo "state-guard: these paths changed without a STATE.md update:"
  echo "$code" | sed 's/^/  /'
  echo "Update STATE.md in the same PR, or title every commit chore: / deps:."
  exit 1
fi
echo "state-guard: escape-hatch commits only"
