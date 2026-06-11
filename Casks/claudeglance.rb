cask "claudeglance" do
  version "1.2.2"
  sha256 "9fe860120920cae971bcf0b6b00ca92f54d902496940c25ed621b4a287ed65bb"

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
