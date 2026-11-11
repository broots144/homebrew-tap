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
  # The function calls `reached` just before the assertion that shows the bug.
  # A failure before that point (broken setup) is a real FAIL, not an xfail.
  local name=$1 fn=$2 reason=$3
  local d out rc; d=$(mktemp -d "$WORK/t.XXXX")
  out=$(set -e; cd "$d"; "$fn" 2>&1); rc=$?
  if [ $rc -eq 0 ]; then xpass=$((xpass+1)); echo "XPASS $name (fixed? drop the xfail: $reason)"
  elif [ -e "$d/.reached" ]; then xfail=$((xfail+1)); echo "xfail $name ($reason)"
  else fail=$((fail+1)); echo "FAIL  $name (failed before the known-bug assertion)"; echo "$out"; fi
}
reached() { : > "$XFAIL_DIR/.reached"; }

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
cu_bad_non_last_cask_fails() {
  # A 404 on a cask that is not the last one must still fail the check.
  mkdir -p bin
  cat > bin/curl <<'EOF2'
#!/usr/bin/env bash
case "$*" in *a.dmg*) printf 404;; *) printf 200;; esac
EOF2
  chmod +x bin/curl; export PATH="$PWD/bin:$PATH"
  mk_cask c/a.rb 1.0 'https://example.invalid/a.dmg'
  mk_cask c/b.rb 1.0 'https://example.invalid/b.dmg'
  run "$SCRIPTS/check-urls.sh" c
  check "exit non-zero" [ $RC -ne 0 ]; check "shows 404" has "404 https://example.invalid/a.dmg"
}
cu_version_substituted_literally() {
  # Characters special to sed in the version must not change the URL.
  fake_curl 200 0
  mk_cask c/x.rb '1.0&b/c' 'https://example.invalid/#{version}.dmg'
  run "$SCRIPTS/check-urls.sh" c
  check "exit 0" [ $RC -eq 0 ]; check "literal version" has '200 https://example.invalid/1.0&b/c.dmg'
}
cu_no_casks_fails() {
  fake_curl 200 0; mkdir -p empty
  run "$SCRIPTS/check-urls.sh" empty
  check "exit 1" [ $RC -eq 1 ]
  check "curl never called" [ ! -e curl.log ]
}

# ---------- check-cask-template.sh ----------
FIXTURES=$ROOT/tests/fixtures
SHA64=b11a08950ceb8a27b914326d0bb41c45d2c73beab7a710ec6a1ad3f114a16fe7
render() { # render <variant> <version> [sha]: a cask as the release job would write it
  sed -e "s/@VERSION@/$2/" -e "s/@SHA256@/${3:-$SHA64}/" "$FIXTURES/claudeglance.$1.rb.tmpl"
}
ctpl() { run "$SCRIPTS/check-cask-template.sh" c.rb "$FIXTURES"; }
ct_adhoc_ok() { render adhoc 1.2.3 > c.rb; ctpl; check "exit 0" [ $RC -eq 0 ]; check "names template" has "adhoc"; }
ct_notarized_ok() { render notarized 2.0.0.1 > c.rb; ctpl; check "exit 0" [ $RC -eq 0 ]; check "names template" has "notarized"; }
ct_url_substring_trick_fails() {
  # The review's proof of concept: the real URL as a query string of another host.
  render adhoc 1.2.3 | sed 's|  url "https://github.com|  url "https://evil.example/x?https://github.com|' > c.rb; ctpl
  check "exit 1" [ $RC -eq 1 ]; check "reason" has "not exactly the workshop144 release URL"
}
ct_postflight_fails() {
  { render adhoc 1.2.3 | sed '$d'; printf '  postflight do\n    puts 1\n  end\nend\n'; } > c.rb; ctpl
  check "exit 1" [ $RC -eq 1 ]; check "reason" has "code-running stanza"
}
ct_shellouts_fail() {
  local l; for l in '  preflight do; end' '  x = `id`' '  x = %x(id)' '  system "id"' '  system_command "/bin/id"' '  installer script: "x"'; do
    { render adhoc 1.2.3 | sed '$d'; printf '%s\nend\n' "$l"; } > c.rb; ctpl
    check "'$l' rejected" [ $RC -eq 1 ]
  done
}
ct_extra_stanza_fails() {
  { render adhoc 1.2.3 | sed '$d'; printf '  depends_on formula: "wget"\nend\n'; } > c.rb; ctpl
  check "exit 1" [ $RC -eq 1 ]; check "says no template" has "matches no template"
}
ct_changed_field_fails() {
  render adhoc 1.2.3 | sed 's|app "ClaudeGlance.app"|app "Other.app"|' > c.rb; ctpl; check "app changed" [ $RC -eq 1 ]
}
ct_bad_fill_ins_fail() {
  render adhoc '1.2.3-evil' > c.rb; ctpl; check "bad version" [ $RC -eq 1 ]
  render adhoc 1.2.3 "${SHA64:0:63}" > c.rb; ctpl; check "short sha" [ $RC -eq 1 ]
  render adhoc 1.2.3 "$(tr a-f A-F <<<"$SHA64")" > c.rb; ctpl; check "upper-case sha" [ $RC -eq 1 ]
}
ct_missing_cask_fails() { ctpl; check "exit 1" [ $RC -eq 1 ]; }
ct_auto_updates_pairing() {
  # Sparkle (claudeglance D-011): only the notarized cask says auto_updates true; the
  # ad-hoc one has no feed, so it says false and keeps the Gatekeeper caveat.
  render notarized 1.9.1 | sed '/^  auto_updates true$/d' > c.rb; ctpl; check "notarized without auto_updates" [ $RC -eq 1 ]
  render notarized 1.9.1 | sed 's/^  auto_updates true$/  auto_updates false/' > c.rb; ctpl; check "notarized with false" [ $RC -eq 1 ]
  render adhoc 1.9.1 | sed 's/^  auto_updates false$/  auto_updates true/' > c.rb; ctpl; check "ad-hoc with true" [ $RC -eq 1 ]
  check "adhoc fixture says false" grep -qx '  auto_updates false' "$FIXTURES/claudeglance.adhoc.rb.tmpl"
  check "notarized fixture says true" grep -qx '  auto_updates true' "$FIXTURES/claudeglance.notarized.rb.tmpl"
}

# ---------- audit-push.sh (gh faked) ----------
fake_gh() { # verified shas listed in ./verified; ./gh_fail makes every call fail
  mkdir -p bin
  cat > bin/gh <<GHEOF
#!/usr/bin/env bash
[ -e "$PWD/gh_fail" ] && { echo "HTTP 502" >&2; exit 1; }
sha=\${2##*/}
if grep -qx "\$sha" "$PWD/verified" 2>/dev/null; then printf 'true\tweb-flow\n'; else printf 'false\t\n'; fi
GHEOF
  chmod +x bin/gh; export PATH="$PWD/bin:$PATH" GH_REPO=test/tap
}
cask_repo() { # cask_repo <version>: repo on main with the cask at <version>; base sha in $BASE
  AP_TOP=$PWD; fake_gh
  local d; d=$(mktemp -d "$WORK/repo.XXXX"); cd "$d"; git init -q -b main .
  mkdir -p Casks scripts; render adhoc "$1" > Casks/claudeglance.rb; echo s > STATE.md
  git add -A; git commit -qm init; BASE=$(git rev-parse HEAD)
}
bump() { # bump <version> [subject]: bot-style commit of the cask at <version>
  render adhoc "$1" > Casks/claudeglance.rb; git add -A; git commit -qm "${2:-Update claudeglance to $1}"
}
verify_head() { git rev-parse HEAD >> "$AP_TOP/verified"; }
audit() { run "$SCRIPTS/audit-push.sh" "$BASE" HEAD; }
ap_bot_bumps_pass() {
  cask_repo 1.9; bump 1.9.1; bump 1.10; audit
  check "exit 0" [ $RC -eq 0 ]; check "1.10 > 1.9.1 (sort -V)" has "bot bump to 1.10"
}
ap_github_merge_passes() {
  cask_repo 1.0; commit "feat: x" scripts/a.sh; verify_head; audit
  check "exit 0" [ $RC -eq 0 ]; check "message" has "merged on GitHub"
}
ap_unverified_commit_fails() {
  cask_repo 1.0; commit "feat: x" scripts/a.sh; audit
  check "exit 1" [ $RC -eq 1 ]; check "reason" has "not a PR merged on GitHub and not a bot bump"
}
ap_bot_touching_other_files_fails() {
  # The finding: a bot-titled push that also edits tests/run.sh or a workflow.
  cask_repo 1.0; render adhoc 1.1 > Casks/claudeglance.rb; mkdir -p tests; echo x > tests/run.sh
  git add -A; git commit -qm "Update claudeglance to 1.1"; audit
  check "exit 1" [ $RC -eq 1 ]; check "reason" has "touches more than Casks/claudeglance.rb"
}
ap_bot_lowering_version_fails() {
  cask_repo 1.8.2; bump 1.8.1; audit
  check "exit 1" [ $RC -eq 1 ]; check "reason" has "version goes from 1.8.2 to 1.8.1"
}
ap_bot_same_version_fails() {
  cask_repo 1.8.2; render adhoc 1.8.2 "$(printf '%064d' 0)" > Casks/claudeglance.rb
  git add -A; git commit -qm "Update claudeglance to 1.8.2"; audit
  check "exit 1" [ $RC -eq 1 ]; check "reason" has "must increase"
}
ap_bot_subject_mismatch_fails() {
  cask_repo 1.0; bump 1.2 "Update claudeglance to 1.1"; audit
  check "exit 1" [ $RC -eq 1 ]; check "reason" has "subject says 1.1 but the cask says 1.2"
}
ap_unverified_merge_commit_fails() {
  cask_repo 1.0; git checkout -qb side; bump 1.1; git checkout -q main
  commit "other: main moved" other.txt; verify_head
  git merge -q --no-ff -m "Update claudeglance to 1.1" side; audit
  check "exit 1" [ $RC -eq 1 ]; check "reason" has "merge commit"
}
ap_one_bad_commit_among_good_fails() {
  cask_repo 1.0; bump 1.1; commit "fix: sneak" scripts/a.sh; bump 1.2; audit
  check "exit 1" [ $RC -eq 1 ]; check "names the bad one" has "fix: sneak"
  check "still reports the good ones" has "bot bump to 1.2"
}
ap_api_failure_fails_closed() {
  cask_repo 1.0; bump 1.1; : > "$AP_TOP/gh_fail"; audit
  check "exit 1" [ $RC -eq 1 ]; check "reason" has "GitHub API lookup failed"
}
ap_zero_before_audits_head() {
  cask_repo 1.0; commit "feat: x" scripts/a.sh
  run "$SCRIPTS/audit-push.sh" 0000000000000000000000000000000000000000 HEAD
  check "exit 1" [ $RC -eq 1 ]; check "audited head" has "feat: x"
}
ap_needs_repo_name() {
  cask_repo 1.0; bump 1.1; unset GH_REPO; audit; check "exit non-zero" [ $RC -ne 0 ]
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
  # Exact match: a substring check let "https://evil.example/x?https://github.com/..." through.
  local u; u=$(field url)
  check "exact release URL" [ "$u" = 'https://github.com/workshop144/claudeglance/releases/download/v#{version}/ClaudeGlance.dmg' ]
}
cask_matches_release_template() { run "$SCRIPTS/check-cask-template.sh" "$CASK" "$FIXTURES"; check "matches" [ $RC -eq 0 ]; }
cask_quit_id_matches_zap_plist() {
  # uninstall quit: must stop the same bundle id whose prefs zap removes.
  local id; id=$(sed -nE 's/^ *uninstall quit: "([^"]+)".*/\1/p' "$CASK")
  check "has quit id" [ -n "$id" ]
  check "zap plist matches" grep -Fq "~/Library/Preferences/$id.plist" "$CASK"
}
cask_requires_ventura() { check "depends_on macos" grep -Eq '^ *depends_on macos: :ventura' "$CASK"; }
cask_token_matches_filename() { check "token" grep -q '^cask "claudeglance" do' "$CASK"; }

# ---------- workflow and security invariants (static, offline) ----------
WF=$ROOT/.github/workflows
wf_actions_pinned_by_sha() {
  # Every `uses:` is a full 40-hex commit SHA, never a tag or branch.
  local bad; bad=$(grep -hE '^ *(- )?uses:' "$WF"/*.yml | grep -Ev 'uses: [^@ ]+@[0-9a-f]{40}( |$)' || true)
  OUT=$bad; check "unpinned uses" [ -z "$bad" ]
}
wf_top_level_permissions_read_only() {
  local f; for f in "$WF"/*.yml; do
    OUT=$f; check "top-level permissions contents: read" [ "$(grep -A1 '^permissions:' "$f" | tail -1)" = "  contents: read" ]
  done
}
wf_checkout_no_persisted_credentials() {
  local f n m; for f in "$WF"/*.yml; do
    n=$(grep -c 'uses: actions/checkout@' "$f" || true); m=$(grep -c 'persist-credentials: false' "$f" || true)
    OUT=$f; check "persist-credentials false on every checkout" [ "$n" -eq "$m" ]
  done
}
wf_push_failure_opens_issue() {
  # D-004: a failed push to main must alert the owner; only the alert job writes issues.
  local f=$WF/tests.yml
  OUT=$(cat "$f")
  check "runs on push to main" [ "$(grep -A1 '^  push:' "$f" | tail -1)" = "    branches: [main]" ]
  check "alert job on failed push" grep -Fq "if: failure() && github.event_name == 'push'" "$f"
  check "issues: write only once" [ "$(grep -c 'issues: write' "$f")" -eq 1 ]
  check "push-audit job runs the audit" grep -Fq "scripts/audit-push.sh" "$f"
  check "alert waits for push-audit" grep -Fq "needs: [tests, push-audit]" "$f"
  check "no write scopes elsewhere" [ "$(grep -hE '^ +[a-z-]+: write' "$WF"/*.yml | grep -vc 'issues: write')" -eq 0 ]
}
state_documents_deploy_key_risk() {
  # L2 accepted risk stays documented, with the rotation deadline.
  local s=$ROOT/STATE.md; OUT=$(cat "$s")
  check "accepted risk section" grep -q '^## Security' "$s"
  check "deploy key risk cites D-002" grep -Eq 'Accepted risk.*D-002' "$s"
  check "rotation deadline" grep -q '2027-09-27' "$s"
  check "decision recorded" grep -q '^## D-004' "$ROOT/docs/DECISIONS.md"
}

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
t "state-guard: merges-only range needs STATE"   sg_merges_only_range_needs_state
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
t "check-urls: 404 on non-last cask fails"       cu_bad_non_last_cask_fails
t "check-urls: version substituted literally"     cu_version_substituted_literally
t "check-urls: no casks fails"                    cu_no_casks_fails
t "cask-template: ad-hoc variant passes"          ct_adhoc_ok
t "cask-template: notarized variant passes"       ct_notarized_ok
t "cask-template: URL substring trick fails"      ct_url_substring_trick_fails
t "cask-template: postflight fails"               ct_postflight_fails
t "cask-template: shell-outs fail"                ct_shellouts_fail
t "cask-template: extra stanza fails"             ct_extra_stanza_fails
t "cask-template: changed field fails"            ct_changed_field_fails
t "cask-template: bad version/sha fill-ins fail"  ct_bad_fill_ins_fail
t "cask-template: missing cask fails"             ct_missing_cask_fails
t "cask-template: auto_updates matches signing"  ct_auto_updates_pairing
t "audit-push: bot bumps pass (sort -V)"          ap_bot_bumps_pass
t "audit-push: GitHub-merged commit passes"       ap_github_merge_passes
t "audit-push: unverified commit fails"           ap_unverified_commit_fails
t "audit-push: bot touching other files fails"    ap_bot_touching_other_files_fails
t "audit-push: lowered version fails"             ap_bot_lowering_version_fails
t "audit-push: same version fails"                ap_bot_same_version_fails
t "audit-push: subject/cask mismatch fails"       ap_bot_subject_mismatch_fails
t "audit-push: unverified merge commit fails"     ap_unverified_merge_commit_fails
t "audit-push: one bad commit fails the push"     ap_one_bad_commit_among_good_fails
t "audit-push: API failure fails closed"          ap_api_failure_fails_closed
t "audit-push: zero before audits head"           ap_zero_before_audits_head
t "audit-push: GH_REPO required"                  ap_needs_repo_name
t "cask: parses"                                  cask_parses
t "cask: version matches tag rule"                cask_version_matches_release_tag_rule
t "cask: sha256 is 64 hex"                        cask_sha256_is_hex64
t "cask: url is exactly the workshop144 release"  cask_url_points_at_workshop144_release
t "cask: matches the release template"            cask_matches_release_template
t "cask: quit id matches zap plist"               cask_quit_id_matches_zap_plist
t "cask: depends_on macos ventura"                cask_requires_ventura
t "cask: token matches file"                      cask_token_matches_filename
t "workflows: actions pinned by SHA"              wf_actions_pinned_by_sha
t "workflows: top-level permissions read-only"    wf_top_level_permissions_read_only
t "workflows: checkout without credentials"       wf_checkout_no_persisted_credentials
t "workflows: failed push opens an issue"         wf_push_failure_opens_issue
t "security: deploy key risk documented"          state_documents_deploy_key_risk

echo
echo "$pass passed, $fail failed, $xfail xfailed, $xpass xpassed"
[ $fail -eq 0 ]
