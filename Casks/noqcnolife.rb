cask "noqcnolife" do
  version "2.0.0"
  sha256 "c8ebd11ad85e2268a9cae0b023064b0356a6c42b967d8f824673c7ed0746d35d"

  url "https://github.com/balcsida/NoQCNoLife/releases/download/v#{version}/NoQCNoLife-#{version}.dmg"
  name "No QC, No Life"
  desc "Control Bose QuietComfort headphones from macOS"
  homepage "https://github.com/balcsida/NoQCNoLife"

  auto_updates false

  app "NoQCNoLife.app"

  postflight do
    system "xattr", "-cr", "#{appdir}/NoQCNoLife.app"
  end

  uninstall quit: "io.github.balcsida.NoQCNoLife"

  zap trash: [
    "~/Library/Preferences/io.github.balcsida.NoQCNoLife.plist",
    "~/Library/Application Support/NoQCNoLife",
  ]
end
