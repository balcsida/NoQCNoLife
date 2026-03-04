#!/bin/bash

# Script to update the Homebrew cask after a release
# Usage: ./scripts/update-homebrew-tap.sh <version> <sha256>

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <version> <sha256>"
    echo "Example: $0 1.3.0 abc123def456..."
    exit 1
fi

VERSION=$1
SHA256=$2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CASK_FILE="$REPO_ROOT/Casks/noqcnolife.rb"

echo "Updating Homebrew cask for NoQCNoLife v${VERSION}..."

# Check if Casks directory exists
if [ ! -d "$REPO_ROOT/Casks" ]; then
    echo "Error: Casks directory not found at $REPO_ROOT/Casks"
    exit 1
fi

# Create the updated cask
cat > "$CASK_FILE" << EOF
cask "noqcnolife" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://github.com/balcsida/NoQCNoLife/releases/download/v#{version}/NoQCNoLife-#{version}.dmg"
  name "No QC, No Life"
  desc "Control Bose QuietComfort headphones from macOS"
  homepage "https://github.com/balcsida/NoQCNoLife"

  auto_updates false

  app "NoQCNoLife.app"

  uninstall quit: "io.github.balcsida.NoQCNoLife"

  zap trash: [
    "~/Library/Preferences/io.github.balcsida.NoQCNoLife.plist",
    "~/Library/Application Support/NoQCNoLife",
  ]
end
EOF

echo ""
echo "Homebrew cask updated at $CASK_FILE"
echo ""
echo "To commit the changes:"
echo "  git add Casks/noqcnolife.rb"
echo "  git commit -m \"Update Homebrew cask to v${VERSION}\""
echo "  git push"
echo ""
echo "Users can then update with:"
echo "  brew update"
echo "  brew upgrade --cask noqcnolife"
