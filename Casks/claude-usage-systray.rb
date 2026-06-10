cask "claude-usage-systray" do
  version "1.1.2"
  sha256 "79a190c662ece68b66cc14dbc705a34ac14dcc89ee00f8c122045e1443ba7e36"

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