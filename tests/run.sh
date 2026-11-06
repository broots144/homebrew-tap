#!/usr/bin/env bash
# Offline test suite for the tap's scripts and cask. No network, no real repos:
# every git repo and cask is synthetic in a temp dir, and curl is a fake on PATH.
# Usage: tests/run.sh            (exit 1 on any unexpected failure)
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPTS=$ROOT/scripts
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Isolate git from the runner's config (signing, hooks, default branch).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME="Test Bot" GIT_AUTHOR_EMAIL="test@example.invalid"
export GIT_COMMITTER_NAME="Test Bot" GIT_COMMITTER_EMAIL="test@example.invalid"

pass=0 fail=0 xfail=0 xpass=0
OUT=""   # output of the last `run`
RC=0     # exit code of the last `run`

run() { OUT=$("$@" 2>&1) && RC=0 || RC=$?; }
check() { # check <description> <condition...>
  if "${@:2}"; then return 0; fi
  echo "    assertion failed: $1"; echo "    rc=$RC output:"; echo "$OUT" | sed 's/^/      /'
  return 1
}
has() { grep -qF -- "$1" <<<"$OUT"; }

t() { # t <name> <function>
  local name=$1 fn=$2
  # Not in an `if`: errexit is ignored in conditions, and every failed check must abort.
  local rc; (set -e; cd "$(mktemp -d "$WORK/t.XXXX")"; "$fn"); rc=$?
  if [ $rc -eq 0 ]; then pass=$((pass+1)); echo "ok    $name"
  else fail=$((fail+1)); echo "FAIL  $name"; fi
}
t_xfail() { # t_xfail <name> <function> <reason>: known bug, must not break the suite
  local name=$1 fn=$2 reason=$3
  local rc; (set -e; cd "$(mktemp -d "$WORK/t.XXXX")"; "$fn") >/dev/null; rc=$?
  if [ $rc -eq 0 ]; then xpass=$((xpass+1)); echo "XPASS $name (fixed? drop the xfail: $reason)"
  else xfail=$((xfail+1)); echo "xfail $name ($reason)"; fi
}

# ---------- helpers: synthetic git repo ----------
# new_repo: fresh repo in a new dir with one base commit on `main`, then a
# `feature` branch checked out. Prints nothing; cds into the repo.
new_repo() {
  local d; d=$(mktemp -d "$WORK/repo.XXXX"); cd "$d"
  git init -q -b main .
  mkdir -p Casks docs scripts
  echo "# state" > STATE.md; echo "cask" > Casks/a.rb
  git add -A; git commit -qm "init"
  git checkout -qb feature
}
commit() { # commit <subject> <path>...: touch each path and commit
  local msg=$1; shift
  for p in "$@"; do mkdir -p "$(dirname "$p")"; echo "$RANDOM $msg" >> "$p"; done
  git add -A; git commit -qm "$msg"
}
guard() { run "$SCRIPTS/state-guard.sh" main; }

# ---------- state-guard.sh ----------
sg_no_changes() {
  new_repo; guard
  check "exit 0" [ $RC -eq 0 ]; check "message" has "no changes vs main"
}
sg_state_updated() {
  new_repo; commit "feat: x" Casks/a.rb STATE.md; guard
  check "exit 0" [ $RC -eq 0 ]; check "message" has "STATE.md updated"
}
sg_docs_only() {
  new_repo; commit "docs: x" LESSONS.md ROADMAP.md README.md docs/DECISIONS.md docs/plans/p9.md; guard
  check "exit 0" [ $RC -eq 0 ]; check "message" has "docs-only change"
}
sg_code_without_state_fails() {
  new_repo; commit "fix: x" scripts/foo.sh; guard
  check "exit 1" [ $RC -eq 1 ]
  check "names the path" has "  scripts/foo.sh"
  check "tells how to fix" has "Update STATE.md in the same PR"
}
sg_mixed_docs_and_code_lists_only_code() {
  new_repo; commit "fix: x" docs/x.md Casks/a.rb; guard
  check "exit 1" [ $RC -eq 1 ]; check "lists cask" has "  Casks/a.rb"
  check "does not list docs" bash -c '! grep -q "docs/x.md" <<<"$0"' "$OUT"
}
sg_nested_readme_is_code() {
  # Only the top-level README.md is a doc; anchors must not leak to subdirs.
  new_repo; commit "fix: x" scripts/README.md; guard
  check "exit 1" [ $RC -eq 1 ]
}
sg_escape_hatch_chore_deps_scoped_bang() {
  new_repo
  commit "chore: tidy" scripts/a.sh
  commit "deps(actions): bump" .github/workflows/x.yml
  commit "chore(ci)!: breaking" scripts/b.sh
  guard
  check "exit 0" [ $RC -eq 0 ]; check "message" has "escape-hatch commits only"
}
sg_escape_hatch_bot_bump() {
  new_repo; commit "Update claudeglance to 9.9.9" Casks/a.rb; guard
  check "exit 0" [ $RC -eq 0 ]
}
sg_escape_hatch_needs_every_commit() {
  new_repo; commit "chore: tidy" scripts/a.sh; commit "feat: sneak" scripts/b.sh; guard
  check "exit 1" [ $RC -eq 1 ]
}
sg_escape_hatch_rejects_lookalikes() {
  local s
  for s in "chores: x" "Chore: x" "chore x" "chore(): x" "update claudeglance to 1.0" "fix: chore: x"; do
    new_repo; commit "$s" scripts/a.sh; guard
    check "subject '$s' must not escape" [ $RC -eq 1 ]
  done
}
sg_ci_merge_ref_ignored() {
  # CI checks out refs/pull/N/merge: a "Merge X into Y" commit on top of the PR.
  new_repo; commit "chore: tidy" scripts/a.sh
  git checkout -q main; commit "other: main moved" other.txt
  git merge -q --no-ff -m "Merge abc123 into def456" feature
  # Base is the pre-merge main, as in CI (origin/<base_ref>).
  run "$SCRIPTS/state-guard.sh" HEAD^1
  check "exit 0" [ $RC -eq 0 ]; check "message" has "escape-hatch commits only"
}
sg_merges_only_range_needs_state() {
  # A merge whose only change is its own content (no non-merge commits in range)
  # has nothing to vouch for it, so it must not pass via the escape hatch.
  new_repo; git checkout -q main; commit "chore: second" x.txt; git checkout -q feature
  git reset -q --hard main
  echo evil > scripts/evil.sh; git add -A
  local tree head; tree=$(git write-tree)
  head=$(git commit-tree "$tree" -p main -p main~1 -m "Merge branch 'x'")
  git reset -q --hard "$head"
  guard
  check "exit 1" [ $RC -eq 1 ]
}
sg_bad_base_fails_loudly() {
  new_repo; run "$SCRIPTS/state-guard.sh" no-such-ref
  check "non-zero exit" [ $RC -ne 0 ]
}
sg_default_base_is_origin_main() {
  new_repo; local d=$PWD
  git clone -q "$d" "$d.clone"; cd "$d.clone"
  git checkout -qb pr; commit "fix: x" scripts/a.sh
  run "$SCRIPTS/state-guard.sh"
  check "exit 1 against origin/main" [ $RC -eq 1 ]; check "path" has "scripts/a.sh"
}

# ---------- check-syntax.sh ----------
cs_ok() {
  mkdir -p c && printf 'cask "a" do\n  version "1.0"\nend\n' > c/a.rb
  run "$SCRIPTS/check-syntax.sh" c
  check "exit 0" [ $RC -eq 0 ]; check "ruby says ok" has "Syntax OK"
}
cs_broken_first_file_fails() {
  # A broken cask that is not the last one must still fail the check.
  mkdir -p c && printf 'cask "a" do\n' > c/a.rb && printf 'cask "b" do\nend\n' > c/b.rb
  run "$SCRIPTS/check-syntax.sh" c
  check "exit non-zero" [ $RC -ne 0 ]
}
cs_no_casks_fails() {
  mkdir -p empty; run "$SCRIPTS/check-syntax.sh" empty
  check "exit 1" [ $RC -eq 1 ]; check "message" has "no casks"
}

# ---------- check-urls.sh (curl faked) ----------
fake_curl() { # fake_curl <stdout> <exit>: curl that logs its args
  mkdir -p bin
  cat > bin/curl <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$PWD/curl.log"
printf '%s' "$1"
exit $2
EOF
  chmod +x bin/curl
  export PATH="$PWD/bin:$PATH"
}
mk_cask() { # mk_cask <file> <version> <url>
  mkdir -p "$(dirname "$1")"
  printf 'cask "x" do\n  version "%s"\n  sha256 "0"\n\n  url "%s"\nend\n' "$2" "$3" > "$1"
}
cu_200_passes_and_expands_version() {
  fake_curl 200 0
  mk_cask c/x.rb 1.2.3 'https://example.invalid/v#{version}/X.dmg'
  run "$SCRIPTS/check-urls.sh" c
  check "exit 0" [ $RC -eq 0 ]
  check "prints code and url" has "200 https://example.invalid/v1.2.3/X.dmg"
  check "curl is bounded" grep -q -- "--max-time 60" curl.log
}
cu_expands_every_version_placeholder() {
  fake_curl 200 0
  mk_cask c/x.rb 2.0 'https://example.invalid/v#{version}/X-#{version}.dmg'
  run "$SCRIPTS/check-urls.sh" c
  check "both placeholders expanded" has "200 https://example.invalid/v2.0/X-2.0.dmg"
}
cu_404_fails() {
  fake_curl 404 0
  mk_cask c/x.rb 1.0 'https://example.invalid/#{version}.dmg'
  run "$SCRIPTS/check-urls.sh" c
  check "exit non-zero" [ $RC -ne 0 ]; check "shows code" has "404 https://example.invalid/1.0.dmg"
}
cu_network_failure_prints_000() {
  fake_curl "" 7
  mk_cask c/x.rb 1.0 'https://example.invalid/#{version}.dmg'
  run "$SCRIPTS/check-urls.sh" c
  check "exit non-zero" [ $RC -ne 0 ]; check "prints 000" has "000 https://example.invalid/1.0.dmg"
}
cu_any_bad_cask_fails() {
  fake_curl 200 0
  mk_cask c/a.rb 1.0 'https://example.invalid/a.dmg'
  printf 'cask "b" do\nend\n' > c/b.rb
  run "$SCRIPTS/check-urls.sh" c
  check "exit 1" [ $RC -eq 1 ]; check "names the file" has "no version or url in c/b.rb"
}
cu_no_casks_fails() {
  fake_curl 200 0; mkdir -p empty
  run "$SCRIPTS/check-urls.sh" empty
  check "exit 1" [ $RC -eq 1 ]
  check "curl never called" [ ! -e curl.log ]
}

# ---------- the real cask (static, offline) ----------
CASK=$ROOT/Casks/claudeglance.rb
field() { sed -nE "s/^ *$1 \"([^\"]+)\".*/\1/p" "$CASK"; }
cask_parses() { run ruby -c "$CASK"; check "Syntax OK" has "Syntax OK"; }
cask_version_matches_release_tag_rule() {
  # Same rule the release job enforces on tags (STATE.md).
  check "version format" grep -Eq '^[0-9]+(\.[0-9]+){1,3}$' <<<"$(field version)"
}
cask_sha256_is_hex64() { check "sha256" grep -Eq '^[0-9a-f]{64}$' <<<"$(field sha256)"; }
cask_url_points_at_workshop144_release() {
  local u; u=$(field url)
  check "versioned release URL" grep -Fq 'https://github.com/workshop144/claudeglance/releases/download/v#{version}/' <<<"$u"
}
cask_quit_id_matches_zap_plist() {
  # uninstall quit: must stop the same bundle id whose prefs zap removes.
  local id; id=$(sed -nE 's/^ *uninstall quit: "([^"]+)".*/\1/p' "$CASK")
  check "has quit id" [ -n "$id" ]
  check "zap plist matches" grep -Fq "~/Library/Preferences/$id.plist" "$CASK"
}
cask_requires_ventura() { check "depends_on macos" grep -Eq '^ *depends_on macos: :ventura' "$CASK"; }
cask_token_matches_filename() { check "token" grep -q '^cask "claudeglance" do' "$CASK"; }

# ---------- run ----------
t "state-guard: no changes"                       sg_no_changes
t "state-guard: STATE.md updated passes"          sg_state_updated
t "state-guard: docs-only passes"                 sg_docs_only
t "state-guard: code without STATE fails"         sg_code_without_state_fails
t "state-guard: lists only non-doc paths"         sg_mixed_docs_and_code_lists_only_code
t "state-guard: nested README is code"            sg_nested_readme_is_code
t "state-guard: chore/deps/scope/bang escape"     sg_escape_hatch_chore_deps_scoped_bang
t "state-guard: bot bump escape"                  sg_escape_hatch_bot_bump
t "state-guard: escape needs every commit"        sg_escape_hatch_needs_every_commit
t "state-guard: lookalike subjects rejected"      sg_escape_hatch_rejects_lookalikes
t "state-guard: CI merge ref ignored"             sg_ci_merge_ref_ignored
t_xfail "state-guard: merges-only range needs STATE" sg_merges_only_range_needs_state \
  "known bug, fix in open PR #3 (empty --no-merges log passes the escape hatch)"
t "state-guard: unknown base fails"               sg_bad_base_fails_loudly
t "state-guard: default base origin/main"         sg_default_base_is_origin_main
t "check-syntax: valid cask"                      cs_ok
t "check-syntax: broken non-last cask fails"      cs_broken_first_file_fails
t "check-syntax: no casks fails"                  cs_no_casks_fails
t "check-urls: 200 passes, version expanded"      cu_200_passes_and_expands_version
t "check-urls: every #{version} expanded"         cu_expands_every_version_placeholder
t "check-urls: 404 fails"                         cu_404_fails
t "check-urls: network failure prints 000"        cu_network_failure_prints_000
t "check-urls: cask without url fails"            cu_any_bad_cask_fails
t "check-urls: no casks fails"                    cu_no_casks_fails
t "cask: parses"                                  cask_parses
t "cask: version matches tag rule"                cask_version_matches_release_tag_rule
t "cask: sha256 is 64 hex"                        cask_sha256_is_hex64
t "cask: url is workshop144 release"              cask_url_points_at_workshop144_release
t "cask: quit id matches zap plist"               cask_quit_id_matches_zap_plist
t "cask: depends_on macos ventura"                cask_requires_ventura
t "cask: token matches file"                      cask_token_matches_filename

echo
echo "$pass passed, $fail failed, $xfail xfailed, $xpass xpassed"
[ $fail -eq 0 ]
