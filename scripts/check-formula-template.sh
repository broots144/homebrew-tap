#!/usr/bin/env bash
# The formula must be exactly what the audiobook-fetch release job generates
# (D-006): the committed template with only the version and the four sha256
# values filled in. Anything else (another URL, an extra method, a shell-out)
# fails, so the `tests` workflow and its alert job catch a hand-crafted formula
# pushed with the deploy key. A tap with no formula yet passes: there is
# nothing to install from.
# Usage: scripts/check-formula-template.sh [formula] [template-dir]
set -euo pipefail
formula=${1:-Formula/audiobook-fetch.rb}
tmpl=${2:-tests/fixtures}/audiobook-fetch.rb.tmpl
[ -f "$formula" ] || { echo "formula-template: no formula at $formula (nothing to check)"; exit 0; }
[ -f "$tmpl" ] || { echo "formula-template: no template at $tmpl"; exit 1; }

# Shell-outs and code-running hooks are never part of the template. Checked
# separately so the failure names the reason, not only a diff. (`def install`
# with `bin.install` is the template's one method body and is matched exactly
# by the comparison below.)
if grep -nE '(^|[^[:alnum:]_])(preflight|postflight|post_install|uninstall_preflight|uninstall_postflight|installer|system|system_command|exec|eval|spawn|IO\.popen|Open3|Kernel|`|%x)' "$formula"; then
  echo "formula-template: $formula contains a code-running hook or shell-out"; exit 1
fi

# Fill-ins must match the release job's own validation (tag rule, 64-hex sha).
normalised=$(sed -E \
  -e 's/^  version "[0-9]+(\.[0-9]+){1,3}"$/  version "@VERSION@"/' \
  -e 's/^      sha256 "[0-9a-f]{64}"$/      sha256 "@SHA256@"/' "$formula")
if [ "$normalised" = "$(cat "$tmpl")" ]; then echo "formula-template: $formula matches $(basename "$tmpl")"; exit 0; fi
echo "formula-template: $formula does not match $tmpl:"
diff <(printf '%s\n' "$normalised") "$tmpl" || true
exit 1
