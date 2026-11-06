# Roadmap

Status detail lives in STATE.md.

| Phase | Title | Status | Gate / blocker |
|---|---|---|---|
| P0 | Tap bootstrap (`claude-usage-systray`) | ✅ | `brew install --cask` worked |
| P1 | Rename cask to `claudeglance` | ✅ | old token removed |
| P2 | Release job bumps the cask | ✅ | bot commit per release tag |
| P3 | URL moved to workshop144/claudeglance | ✅ | DMG URL returns 200 |
| P4 | Repo-state pattern retrofit | ✅ | `just verify-phase-4` |
| P5 | Cask passes `brew style` | ⬜ | template fix in claudeglance release.yml, then `just verify-phase-5` |
| P6 | Notarized build, no Gatekeeper caveat | ⏸ | needs Apple Developer ID signing secrets |
