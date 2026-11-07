#!/usr/bin/env bash
# Audit every commit a push added to main (D-005). Two shapes are allowed:
#   1. A PR merged on GitHub: GitHub reports the commit as verified and the
#      committer is web-flow (only GitHub can sign those; the deploy key cannot).
#   2. A release bot bump: subject "Update claudeglance to X.Y.Z", one parent,
#      touches only Casks/claudeglance.rb, the cask version equals X.Y.Z and is
#      strictly higher than the parent's.
# Anything else fails, and the `alert` job in tests.yml opens an issue.
# Usage: scripts/audit-push.sh <before-sha> <after-sha>
# Needs GH_REPO (owner/name) and a token gh can use (GH_TOKEN in CI).
set -euo pipefail
before=${1:?before sha}; after=${2:?after sha}
: "${GH_REPO:?GH_REPO must be set to owner/name}"
CASK=Casks/claudeglance.rb

if [[ "$before" =~ ^0+$ ]]; then range=("$after" -1)   # first push of the branch
else range=("$before..$after"); fi
commits=$(git rev-list --reverse "${range[@]}")
[ -n "$commits" ] || { echo "audit-push: no new commits"; exit 0; }

cask_version() { git show "$1:$CASK" 2>/dev/null | sed -nE 's/^  version "([^"]+)"$/\1/p'; }

github_merged() { # verified commit whose committer is GitHub's web-flow
  local info
  info=$(gh api "repos/$GH_REPO/commits/$1" --jq '[.commit.verification.verified, (.committer.login // "")] | @tsv') || {
    echo "audit-push: could not read commit $1 from the GitHub API" >&2; return 2; }
  [ "$info" = "$(printf 'true\tweb-flow')" ]
}

bot_bump_problem() { # prints why $1 is not a valid bot bump; empty when it is
  local c=$1 subject v parents files new old
  subject=$(git log -1 --format=%s "$c")
  parents=$(git rev-list --parents -n1 "$c" | wc -w | tr -d ' ')
  [[ "$subject" =~ ^Update\ claudeglance\ to\ ([0-9]+(\.[0-9]+){1,3})$ ]] || { echo "not a PR merged on GitHub and not a bot bump"; return; }
  v=${BASH_REMATCH[1]}
  [ "$parents" -eq 2 ] || { echo "bot bump is a merge commit"; return; }
  files=$(git diff-tree --no-commit-id --name-only -r "$c")
  [ "$files" = "$CASK" ] || { echo "bot bump touches more than $CASK: $(echo $files)"; return; }
  new=$(cask_version "$c"); old=$(cask_version "$c^")
  [ "$new" = "$v" ] || { echo "subject says $v but the cask says ${new:-nothing}"; return; }
  if [ -n "$old" ]; then
    [ "$old" != "$new" ] && [ "$(printf '%s\n%s\n' "$old" "$new" | sort -V | tail -1)" = "$new" ] \
      || { echo "version goes from $old to $new (must increase)"; return; }
  fi
}

bad=0
for c in $commits; do
  short=$(git rev-parse --short "$c")
  rc=0; github_merged "$c" || rc=$?
  if [ $rc -eq 0 ]; then echo "ok   $short merged on GitHub"; continue; fi
  if [ $rc -eq 2 ]; then echo "FAIL $short GitHub API lookup failed"; bad=1; continue; fi
  why=$(bot_bump_problem "$c")
  if [ -z "$why" ]; then echo "ok   $short bot bump to $(cask_version "$c")"
  else echo "FAIL $short $(git log -1 --format=%s "$c"): $why"; bad=1; fi
done
[ $bad -eq 0 ] || { echo "audit-push: unexpected commit(s) on main. See D-005: revert, delete the deploy key, rotate."; exit 1; }
echo "audit-push: all commits accounted for"
