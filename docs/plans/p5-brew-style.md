# P5: cask passes brew style

Goal: `brew style Casks/claudeglance.rb` reports no offenses, and stays clean across releases.

1. In workshop144/claudeglance `.github/workflows/release.yml`, change the `FORMULA` template:
   - desc without the word "macOS" (for example "Menu bar app showing Claude.ai plan usage in real time").
   - add a `depends_on macos:` line matching the app's deployment target.
   - order stanzas the way Homebrew expects: version, sha256, url, name, desc, homepage, depends_on, app, zap, caveats.
   - sort the `zap trash` paths alphabetically.
2. Run `brew style --fix` on a copy of the rendered cask locally to confirm the template output is clean.
3. Mirror the rendered file into this repo via a PR, run `just verify-phase-5`, paste the output into STATE.md.
4. The next release tag must produce an identical file (bot commit diff limited to version and sha256).
