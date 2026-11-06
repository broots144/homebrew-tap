# homebrew-tap

Homebrew tap `broots144/tap` (public). One cask today: `Casks/claudeglance.rb`, the ClaudeGlance menu bar app built in `workshop144/claudeglance`.

## Session ritual

- Every session, before doing anything: read STATE.md, ROADMAP.md, LESSONS.md, then the task or phase prompt.
- State is in the repo, not in memory. Update STATE.md when you finish meaningful work. Commit before stopping.
- If stuck, write a clear BLOCKED entry in STATE.md with exact next steps.
- Decisions go in docs/DECISIONS.md (D-NNN, append only, supersede instead of rewriting). Phase plans go in docs/plans/ before building.

## How this repo is written to

- `Casks/claudeglance.rb` is generated. The `homebrew-tap` job in `workshop144/claudeglance` `.github/workflows/release.yml` rewrites the whole file on every release tag and pushes straight to `main` with a write deploy key ("claudeglance release (write)"). Hand edits to the cask are overwritten on the next release: change the template in release.yml instead, then (optionally) mirror the change here.
- Bot commits are titled `Update claudeglance to X.Y.Z`. They do not touch STATE.md; that is expected.
- `main` has a ruleset blocking force-push and deletion. Do not add required status checks or PR-only rules to `main`: the release job pushes directly and would be blocked.
- Human changes go through a branch and PR. Run `just check` first.

## Rules

- Public repo: never commit personal data (real names, addresses, phone numbers, personal emails). The bot identity is the GitHub noreply address only.
- Never commit the deploy key or any token. The private half lives only as the `HOMEBREW_TAP_DEPLOY_KEY` secret in workshop144/claudeglance.
- No em dashes or en dashes in the state files.
- Commit trailers: end commit messages with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` when Claude authored the change.
