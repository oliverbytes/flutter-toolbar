cask "flunner" do
  version "1.0.0"
  sha256 "4b4355ae53d57e6e96a8413ebb4ccdc6952d58f120d3c5432f0c220e91f9dfc8"

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
