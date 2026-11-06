# Homebrew tap checks. Run `just check` before opening a PR.

brew := `command -v brew || echo /opt/homebrew/bin/brew`

default: check

# Syntax, download URL, STATE guard
check: syntax url guard

syntax:
    for f in Casks/*.rb; do ruby -c "$f" || exit 1; done

# Every cask's download URL for its current version answers 200
url:
    #!/usr/bin/env bash
    set -euo pipefail
    for f in Casks/*.rb; do
      v=$(sed -nE 's/^ *version "([^"]+)".*/\1/p' "$f")
      u=$(sed -nE 's/^ *url "([^"]+)".*/\1/p' "$f" | sed "s/#{version}/$v/")
      code=$(curl -sIL -o /dev/null -w '%{http_code}' "$u")
      echo "$code $u"; [ "$code" = 200 ]
    done

guard:
    scripts/state-guard.sh origin/main

# Homebrew's linter. Not part of check until P5 lands.
style:
    {{brew}} style Casks/*.rb

verify-phase-3: url

verify-phase-4:
    test -f STATE.md && test -f ROADMAP.md && test -f LESSONS.md && test -f docs/DECISIONS.md
    grep -q 'read STATE.md, ROADMAP.md, LESSONS.md' CLAUDE.md
    just check

verify-phase-5: check style
