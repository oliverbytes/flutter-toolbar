cask "flunner" do
  version "1.0.0"
  sha256 "2d557d4bb8ce2db03f2d92db9451b2b163eeea273fe56d65d3084117a35b0edf"

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
