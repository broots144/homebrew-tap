cask "claudeglance" do
  version "1.7.3"
  sha256 "b994c56d9a1264fc6f0cbd90ccdabf45c296f334b782cf55cc7c2924fdec5744"

  url "https://github.com/broots144/claudeglance/releases/download/v#{version}/ClaudeGlance.dmg"
  name "ClaudeGlance"
  desc "macOS menu bar app showing Claude.ai plan usage in real time"
  homepage "https://github.com/broots144/claudeglance"

  app "ClaudeGlance.app"

  caveats <<~EOS
    ClaudeGlance is ad-hoc signed (not notarized). On first launch macOS
    may block it. Right-click the app in /Applications and choose Open,
    or run:
      xattr -dr com.apple.quarantine /Applications/ClaudeGlance.app
  EOS

  zap trash: [
    "~/Library/Preferences/io.github.broots144.ClaudeGlance.plist",
    "~/Library/Application Support/ClaudeGlance",
    "~/.claudeglance",
  ]
end