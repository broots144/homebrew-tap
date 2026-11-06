# Lessons

One line per lesson, newest first.

- 2026-11-06: `brew style` was never run on the generated cask and it has 5 offenses. Rule: style fixes go in the release.yml template, and `just style` is the check before tagging.
- 2026-09-27: a token held in the workshop144 org had no write access to this personal-account repo, so the release job switched to a write deploy key scoped to this repo only. Rule: cross-owner pushes use a per-repo deploy key, never a broad PAT.
- 2026-09-26: the source repo moved to workshop144 and the old broots144 release URL stopped redirecting, so installs broke until 7ee90bd. Rule: when the app repo moves, update the URL in release.yml and here in the same change.
- 2026-06-11: the tap token was probed by committing and deleting a `.tap-token-check` file on `main` (c9589a0, 14f05a0). Rule: test write access with `git push --dry-run` or a throwaway branch, not commits on `main`.
- 2026-06-10: early builds were re-uploaded under the same version, forcing sha256-only cask bumps (1395bbd, bc6513c). Rule: never replace a released asset; cut a new version so the sha256 and version move together.
