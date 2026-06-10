cask "claude-usage-systray" do
  version "1.1.0"
  sha256 "79f077108e1e691c1c3a8d6ad2aef45493fdf99c135b5f0a4d88e515038629c7"

  url "https://github.com/broots144/claude-usage-systray/releases/download/v#{version}/ClaudeUsageSystray.dmg"
  name "Claude Usage Systray"
  desc "macOS menu bar app showing Claude.ai plan usage in real time"
  homepage "https://github.com/broots144/claude-usage-systray"

  app "ClaudeUsageSystray.app"

  zap trash: [
    "~/Library/Preferences/com.adntgv.claude-usage-systray.plist",
    "~/Library/Application Support/ClaudeUsageSystray",
  ]
end