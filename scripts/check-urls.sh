#!/usr/bin/env bash
# Every cask's download URL for its current version answers 200.
set -euo pipefail
shopt -s nullglob
# bash 5.2+ would expand & in a ${x//pat/rep} replacement; keep it literal.
# (Quoting "$v" instead would leave literal quotes on macOS /bin/bash 3.2.)
shopt -u patsub_replacement 2>/dev/null || true
dir=${1:-Casks}
casks=("$dir"/*.rb)
[ ${#casks[@]} -gt 0 ] || { echo "check-urls: no casks in $dir"; exit 1; }
for f in "${casks[@]}"; do
  v=$(sed -nE 's/^ *version "([^"]+)".*/\1/p' "$f")
  u=$(sed -nE 's/^ *url "([^"]+)".*/\1/p' "$f")
  # Every #{version} (tag and file name), replaced literally: no sed, so a
  # version with / & or \ cannot break the expression or change the URL.
  u=${u//'#{version}'/$v}
  [ -n "$v" ] && [ -n "$u" ] || { echo "check-urls: no version or url in $f"; exit 1; }
  # Bounded and retried; a network failure prints 000 and fails, never hangs or exits silently.
  code=$(curl -sIL --connect-timeout 10 --max-time 60 --retry 3 --retry-all-errors \
    -o /dev/null -w '%{http_code}' "$u" || true)
  code=${code:-000}
  echo "$code $u"; [ "$code" = 200 ]
done
