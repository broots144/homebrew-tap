cask "claudeglance" do
  version "1.8.1"
  sha256 "64cebff853e86f9bc9bd3c271a1625c963792ef8a5c43c3b4261edd8ad737e53"

  url "https://github.com/workshop144/claudeglance/releases/download/v#{version}/ClaudeGlance.dmg"
  name "ClaudeGlance"
  desc "macOS menu bar app showing Claude.ai plan usage in real time"
  homepage "https://github.com/workshop144/claudeglance"

  depends_on macos: :ventura

  app "ClaudeGlance.app"

  uninstall quit: "io.github.broots144.ClaudeGlance"

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
