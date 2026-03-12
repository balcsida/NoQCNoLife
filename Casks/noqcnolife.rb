cask "noqcnolife" do
  version "1.5.0"
  sha256 "15cff8c1311611c0dce9315c16236f046782c372b103a71ddc0f192b42f4afee"

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
