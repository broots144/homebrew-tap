cask "claudeglance" do
  version "1.8.2"
  sha256 "b11a08950ceb8a27b914326d0bb41c45d2c73beab7a710ec6a1ad3f114a16fe7"

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
