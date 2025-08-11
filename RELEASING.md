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
   - Update the Homebrew tap formula

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

## Homebrew Formula

The Homebrew tap can be **automatically updated** by GitHub Actions when you create a release.

The tap repository is located at: `github.com/balcsida/homebrew-tap`

### Enabling Automatic Updates

To enable automatic Homebrew tap updates:

1. **Create a Fine-grained Personal Access Token**:
   - Go to GitHub Settings → Developer settings → Personal access tokens → Fine-grained tokens
   - Click "Generate new token"
   - Give it a name like "Homebrew Tap Updater"
   - Set expiration (e.g., 90 days or custom)
   - Under "Repository access", select "Selected repositories"
   - Choose only `balcsida/homebrew-tap` repository
   - Under "Permissions" → "Repository permissions", set:
     - **Contents**: Read and Write (to update formula files)
     - **Metadata**: Read (automatically selected)
   - Click "Generate token" and copy it

2. **Add the token as a repository secret**:
   - Go to your NoQCNoLife repository settings
   - Navigate to Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `HOMEBREW_TAP_TOKEN`
   - Value: Paste your Personal Access Token
   - Click "Add secret"

Once configured, the GitHub Action will automatically update the Homebrew tap after each release.

Users can install NoQCNoLife via Homebrew:
```bash
brew tap balcsida/tap
brew install --cask noqcnolife
```

### Manual Update (if needed)

If you need to manually update the Homebrew formula:

1. **Get the SHA256 from the release**:
   ```bash
   shasum -a 256 NoQCNoLife-1.3.0.dmg
   ```

2. **Update the Homebrew tap**:
   ```bash
   ./scripts/update-homebrew-tap.sh 1.3.0 <sha256-hash>
   ```

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