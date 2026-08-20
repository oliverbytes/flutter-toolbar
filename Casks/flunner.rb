cask "flunner" do
  version "1.0.0"
  sha256 "b2f0f2001234620bd85767efa98e2ecda8ce436b2e90863445c578dfa0bdd505"

  url "https://github.com/stackwares/flunner/releases/download/v#{version}/Flunner.dmg"
  name "Flunner"
  desc "Workbench for the Flutter run-observe-reload loop"
  homepage "https://github.com/stackwares/flunner"

  depends_on macos: :sequoia

  app "Flunner.app"

  zap trash: [
    "~/Library/Application Support/Flunner",
    "~/Library/Caches/com.flunner.app",
    "~/Library/Preferences/com.flunner.app.plist",
    "~/Library/Saved Application State/com.flunner.app.savedState",
  ]
end
