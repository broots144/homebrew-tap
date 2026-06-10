cask "claude-usage-systray" do
  version "1.1.1"
  sha256 "036746f515be9d80e5457491693cc76c8aa5070f1fad88b09858c03381f8247c"

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