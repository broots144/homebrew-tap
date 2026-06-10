cask "claudeglance" do
  version "1.1.4"
  sha256 "1b3d17f1529044e20fda4b665ed76cbc0e84f1a930e201f84d60f7d01d71a9fa"

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
  ]
end
