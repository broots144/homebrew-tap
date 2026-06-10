cask "claude-usage-systray" do
  version "1.1.0"
  sha256 "31cf438004753b3c297082600cf75e29b8c5bb52b646532a17586958f3ed767b"

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