cask "claudeglance" do
  version "1.8.4"
  sha256 "228913f87374a4a0f68b2d99162fe64d7e022a7b1c2dd8fcb4406a6fa03b17da"

  url "https://github.com/workshop144/claudeglance/releases/download/v#{version}/ClaudeGlance.dmg"
  name "ClaudeGlance"
  desc "macOS menu bar app showing Claude.ai plan usage in real time"
  homepage "https://github.com/workshop144/claudeglance"

  depends_on macos: :ventura

  app "ClaudeGlance.app"

  uninstall quit: "io.github.broots144.ClaudeGlance"

  zap trash: [
    "~/Library/Preferences/io.github.broots144.ClaudeGlance.plist",
    "~/Library/Application Support/ClaudeGlance",
    "~/.claudeglance",
  ]
end
