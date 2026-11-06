#!/usr/bin/env bash
# Every cask's download URL for its current version answers 200.
set -euo pipefail
shopt -s nullglob
dir=${1:-Casks}
casks=("$dir"/*.rb)
[ ${#casks[@]} -gt 0 ] || { echo "check-urls: no casks in $dir"; exit 1; }
for f in "${casks[@]}"; do
  v=$(sed -nE 's/^ *version "([^"]+)".*/\1/p' "$f")
  # g: a URL may use #{version} more than once (tag and file name).
  u=$(sed -nE 's/^ *url "([^"]+)".*/\1/p' "$f" | sed "s/#{version}/$v/g")
  [ -n "$v" ] && [ -n "$u" ] || { echo "check-urls: no version or url in $f"; exit 1; }
  # Bounded and retried; a network failure prints 000 and fails, never hangs or exits silently.
  code=$(curl -sIL --connect-timeout 10 --max-time 60 --retry 3 --retry-all-errors \
    -o /dev/null -w '%{http_code}' "$u" || true)
  code=${code:-000}
  echo "$code $u"; [ "$code" = 200 ]
done
