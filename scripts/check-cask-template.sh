#!/usr/bin/env bash
# The cask must be exactly what the claudeglance release job generates (D-005):
# the committed template with only the version and sha256 filled in. Anything
# else (another URL, an extra stanza, a postflight hook) fails, so the `tests`
# workflow and its alert job catch a hand-crafted cask pushed with the deploy key.
# Usage: scripts/check-cask-template.sh [cask] [template-dir]
set -euo pipefail
cask=${1:-Casks/claudeglance.rb}
tmpl_dir=${2:-tests/fixtures}
[ -f "$cask" ] || { echo "cask-template: no cask at $cask"; exit 1; }

# Code-running stanzas and shell-outs are never part of the template. Checked
# separately so the failure names the reason, not only a diff.
if grep -nE '(^|[^[:alnum:]_])(preflight|postflight|uninstall_preflight|uninstall_postflight|installer|system|system_command|exec|eval|spawn|IO\.popen|Open3|Kernel|`|%x)' "$cask"; then
  echo "cask-template: $cask contains a code-running stanza or shell-out"; exit 1
fi

url='  url "https://github.com/workshop144/claudeglance/releases/download/v#{version}/ClaudeGlance.dmg"'
grep -qxF -- "$url" "$cask" || { echo "cask-template: $cask url is not exactly the workshop144 release URL"; exit 1; }

# Fill-ins must match the release job's own validation (tag rule, 64-hex sha).
normalised=$(sed -E \
  -e 's/^  version "[0-9]+(\.[0-9]+){1,3}"$/  version "@VERSION@"/' \
  -e 's/^  sha256 "[0-9a-f]{64}"$/  sha256 "@SHA256@"/' "$cask")
for t in "$tmpl_dir"/claudeglance.*.rb.tmpl; do
  [ -f "$t" ] || continue
  if [ "$normalised" = "$(cat "$t")" ]; then echo "cask-template: $cask matches $(basename "$t")"; exit 0; fi
done
echo "cask-template: $cask matches no template in $tmpl_dir. Diff against the closest:"
diff <(printf '%s\n' "$normalised") "$tmpl_dir/claudeglance.adhoc.rb.tmpl" || true
exit 1
