# Release Process

This document describes how to create a new release of NoQCNoLife.

## Prerequisites

- Xcode installed
- GitHub CLI (`gh`) installed
- Write access to the repository

## Automatic Release (Recommended)

1. **Update version in Info.plist**:
   ```bash
   # Update CFBundleShortVersionString in NoQCNoLife/Info.plist
   # Example: 1.3.0
   ```

2. **Commit version bump**:
   ```bash
   git add NoQCNoLife/Info.plist
   git commit -m "Bump version to 1.3.0"
   git push origin master
   ```

3. **Create and push tag**:
   ```bash
   git tag -a v1.3.0 -m "Release v1.3.0"
   git push origin v1.3.0
   ```

4. **GitHub Actions will automatically**:
   - Build the app
   - Create a DMG file
   - Calculate checksums
   - Create a GitHub release
   - Upload the DMG and checksums

## Manual Release (Local)

1. **Build DMG locally**:
   ```bash
   ./scripts/create-dmg.sh 1.3.0
   ```

2. **Create release on GitHub**:
   ```bash
   gh release create v1.3.0 \
     --title "Release v1.3.0" \
     --notes "Release notes here" \
     NoQCNoLife-1.3.0.dmg
   ```

## Update Homebrew Formula

### First Time Setup

1. **Create the tap repository** (only needed once):
   ```bash
   ./scripts/setup-homebrew-tap.sh
   ```
   This will create a new repository at `github.com/balcsida/homebrew-tap`

### After Each Release

1. **Get the SHA256 from the release**:
   ```bash
   shasum -a 256 NoQCNoLife-1.3.0.dmg
   ```

2. **Update the Homebrew tap**:
   ```bash
   ./scripts/update-homebrew-tap.sh 1.3.0 <sha256-hash>
   ```
   This will automatically update and push to your tap repository

## Version Numbering

We use semantic versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Incompatible changes
- **MINOR**: New features, backwards compatible
- **PATCH**: Bug fixes, backwards compatible

## Release Checklist

- [ ] All tests pass
- [ ] No compiler warnings
- [ ] Version updated in Info.plist
- [ ] Changes documented in release notes
- [ ] Tag created and pushed
- [ ] GitHub Actions build successful
- [ ] DMG downloadable from release
- [ ] Homebrew formula updated (if applicable)

## Troubleshooting

### Build fails on GitHub Actions
- Check the build logs in the Actions tab
- Ensure all dependencies are properly specified
- Verify Xcode project settings

### DMG creation fails
- Ensure you have write permissions in the current directory
- Check that the build succeeded
- Verify disk space is available

### Homebrew installation fails
- Verify the SHA256 hash matches the released DMG
- Check the download URL is correct
- Ensure the tap repository is public