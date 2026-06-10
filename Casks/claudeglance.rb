cask "claudeglance" do
  version "1.0.0"
  sha256 "8f6f28b6bedcb475f6e349c3c0cbb4f686941668c1ce2c298342175866af163c"

  url "https://github.com/broots144/claudeglance/releases/download/v#{version}/ClaudeGlance.dmg"
  name "ClaudeGlance"
  desc "macOS menu bar app showing Claude.ai plan usage in real time"
  homepage "https://github.com/broots144/claudeglance"

  app "ClaudeGlance.app"

  zap trash: [
    "~/Library/Preferences/io.github.broots144.ClaudeGlance.plist",
    "~/Library/Application Support/ClaudeGlance",
  ]
end
