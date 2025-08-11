#!/bin/bash

# Script to update the Homebrew tap repository after a release
# Usage: ./scripts/update-homebrew-tap.sh <version> <sha256>

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <version> <sha256>"
    echo "Example: $0 1.3.0 abc123def456..."
    exit 1
fi

VERSION=$1
SHA256=$2
TAP_DIR="../homebrew-tap"

echo "Updating Homebrew tap for NoQCNoLife v${VERSION}..."

# Check if tap repository exists
if [ ! -d "$TAP_DIR" ]; then
    echo "Error: Homebrew tap repository not found at $TAP_DIR"
    echo "Please run ./scripts/setup-homebrew-tap.sh first"
    exit 1
fi

# Create the updated formula
cat > "$TAP_DIR/Casks/noqcnolife.rb" << EOF
cask "noqcnolife" do
  version "${VERSION}"
  sha256 "${SHA256}"

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
EOF

# Commit and push
cd "$TAP_DIR"
git add Casks/noqcnolife.rb
git commit -m "Update NoQCNoLife to v${VERSION}"
git push

echo ""
echo "✅ Homebrew tap updated successfully!"
echo ""
echo "Users can now update with:"
echo "  brew update"
echo "  brew upgrade --cask noqcnolife"