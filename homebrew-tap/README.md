# Homebrew Tap for NoQCNoLife

This Homebrew tap allows you to install NoQCNoLife using Homebrew.

## Installation

### Add the tap and install:
```bash
brew tap balcsida/tap
brew install --cask noqcnolife
```

### Or install directly:
```bash
brew install --cask balcsida/tap/noqcnolife
```

## Uninstallation

```bash
brew uninstall --cask noqcnolife
```

## About NoQCNoLife

NoQCNoLife is a macOS menu bar application for controlling Bose QuietComfort headphones via Bluetooth.

For more information, visit the [main repository](https://github.com/balcsida/NoQCNoLife).

## Creating Your Own Tap Repository

To make this formula available via Homebrew:

1. Create a new repository called `homebrew-tap` in your GitHub account
2. Copy the `noqcnolife.rb` file to the `Casks` directory in that repository
3. Update the SHA256 hash in the formula after each release
4. Users can then install using `brew tap yourusername/tap`

## Updating the Formula

After each new release:
1. Update the `version` in the formula
2. Update the `sha256` hash (get it from the release checksums)
3. Commit and push to your tap repository