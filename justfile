# Homebrew tap checks. Run `just check` before opening a PR.

brew := `command -v brew || echo /opt/homebrew/bin/brew`

default: check

# Syntax, download URL, STATE guard, offline test suite
check: syntax url guard test

syntax:
    scripts/check-syntax.sh

# Every cask's download URL for its current version answers 200
url:
    scripts/check-urls.sh

guard:
    scripts/state-guard.sh origin/main

# Offline tests: synthetic git repos and casks, curl faked on PATH
test:
    tests/run.sh

# Homebrew's linter. Not part of check until P5 lands.
style:
    {{brew}} style Casks/*.rb

verify-phase-3: url

verify-phase-4:
    test -f STATE.md && test -f ROADMAP.md && test -f LESSONS.md && test -f docs/DECISIONS.md
    grep -q 'read STATE.md, ROADMAP.md, LESSONS.md' CLAUDE.md
    just check

verify-phase-5: check style
