cask "claude-usage-systray" do
  version "1.1.0"
  sha256 "09f10b4e010de26f843ab06ecad04cf6bb4be364e770e2aff0a1fd52216094e2"

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