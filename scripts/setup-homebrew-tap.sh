#!/bin/bash

# Script to set up the Homebrew tap repository
# This will create a separate repository for your Homebrew formulas

set -e

echo "Setting up Homebrew tap repository..."
echo ""
echo "This script will help you create a separate homebrew-tap repository"
echo "that will allow users to install NoQCNoLife via Homebrew."
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed."
    echo "Install it with: brew install gh"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo "Please authenticate with GitHub first:"
    gh auth login
fi

# Create the tap repository
echo "Creating homebrew-tap repository on GitHub..."
gh repo create homebrew-tap --public --description "Homebrew tap for NoQCNoLife and other tools" --clone

# Enter the new repository
cd homebrew-tap

# Create the Casks directory (for GUI apps)
mkdir -p Casks

# Copy the formula
cp ../homebrew-tap/noqcnolife.rb Casks/

# Create a README
cat > README.md << 'EOF'
# Homebrew Tap for balcsida

This tap contains Homebrew formulas for my projects.

## Installation

```bash
brew tap balcsida/tap
```

## Available Formulas

### NoQCNoLife

Control Bose QuietComfort headphones from macOS.

```bash
brew install --cask balcsida/tap/noqcnolife
```

Or simply:
```bash
brew install --cask noqcnolife  # after tapping
```

## Uninstallation

```bash
brew uninstall --cask noqcnolife
brew untap balcsida/tap
```

## More Information

- [NoQCNoLife Repository](https://github.com/balcsida/NoQCNoLife)
EOF

# Initialize git and push
git add .
git commit -m "Initial commit with NoQCNoLife cask"
git push -u origin main

cd ..

echo ""
echo "✅ Homebrew tap repository created successfully!"
echo ""
echo "Repository URL: https://github.com/balcsida/homebrew-tap"
echo ""
echo "Users can now install NoQCNoLife with:"
echo "  brew tap balcsida/tap"
echo "  brew install --cask noqcnolife"
echo ""
echo "After each release, update the formula in the tap repository with:"
echo "  ./scripts/update-homebrew-tap.sh <version> <sha256>"