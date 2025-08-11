cask "noqcnolife" do
  version "1.3.0"
  sha256 "PLACEHOLDER_SHA256_WILL_BE_UPDATED_ON_RELEASE"

  url "https://github.com/balcsida/NoQCNoLife/releases/download/v#{version}/NoQCNoLife-#{version}.dmg"
  name "No QC, No Life"
  desc "Control Bose QuietComfort headphones from macOS"
  homepage "https://github.com/balcsida/NoQCNoLife"

  auto_updates false
  depends_on macos: ">= :high_sierra"

  app "NoQCNoLife.app"

  uninstall quit: "io.github.balcsida.NoQCNoLife"

  zap trash: [
    "~/Library/Preferences/io.github.balcsida.NoQCNoLife.plist",
    "~/Library/Application Support/NoQCNoLife",
  ]
end