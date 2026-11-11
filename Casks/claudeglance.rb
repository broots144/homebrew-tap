cask "claudeglance" do
  version "1.9.0"
  sha256 "14999c44d29a1d4f0172f5ed18e572f3f3ad27c4953b09a50c3fbf0ff9915463"

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
