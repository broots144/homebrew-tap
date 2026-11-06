#!/usr/bin/env bash
# Ruby syntax check for every cask. Fails on the first broken file, and when
# there are no casks at all (an empty glob must not pass silently).
set -euo pipefail
shopt -s nullglob
dir=${1:-Casks}
casks=("$dir"/*.rb)
[ ${#casks[@]} -gt 0 ] || { echo "check-syntax: no casks in $dir"; exit 1; }
for f in "${casks[@]}"; do ruby -c "$f"; done
