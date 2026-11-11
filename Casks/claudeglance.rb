cask "claudeglance" do
  version "1.9.1"
  sha256 "33b25891fdd8fd525bfa3b63d997da966c5ea890b1893887e460218e24124b5f"

  url "https://github.com/workshop144/claudeglance/releases/download/v#{version}/ClaudeGlance.dmg"
  name "ClaudeGlance"
  desc "macOS menu bar app showing Claude.ai plan usage in real time"
  homepage "https://github.com/workshop144/claudeglance"

  depends_on macos: :ventura
  auto_updates true

  app "ClaudeGlance.app"

  uninstall quit: "io.github.broots144.ClaudeGlance"

  zap trash: [
    "~/Library/Preferences/io.github.broots144.ClaudeGlance.plist",
    "~/Library/Application Support/ClaudeGlance",
    "~/.claudeglance",
  ]
end
