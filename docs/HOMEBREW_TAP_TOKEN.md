# Setting up Homebrew Tap Auto-Update with Fine-grained Token

This guide explains how to set up automatic Homebrew tap updates using GitHub's fine-grained personal access tokens, which are more secure than classic tokens.

## Why Fine-grained Tokens?

Fine-grained personal access tokens offer better security:
- Limited to specific repositories (only `homebrew-tap` in our case)
- Minimal required permissions (only Contents read/write)
- Can set expiration dates
- Better audit trail

## Step-by-Step Setup

### 1. Create the Fine-grained Token

1. Go to [GitHub Settings → Developer settings → Personal access tokens → Fine-grained tokens](https://github.com/settings/personal-access-tokens/new)

2. Configure the token:
   - **Token name**: `NoQCNoLife Homebrew Tap Updater`
   - **Expiration**: Choose based on your preference (90 days recommended)
   - **Description**: `Allows NoQCNoLife releases to update homebrew-tap`

3. Set **Repository access**:
   - Select "Selected repositories"
   - Click "Select repositories" 
   - Choose only: `balcsida/homebrew-tap`

4. Set **Repository permissions**:
   - Expand "Repository permissions"
   - Find **Contents** and set to: `Read and write`
   - **Metadata** will be automatically set to `Read`
   - All other permissions should remain as "No access"

5. Review the summary:
   ```
   Selected repositories: 1
   - balcsida/homebrew-tap
   
   Repository permissions:
   - Contents: Read and write
   - Metadata: Read
   ```

6. Click "Generate token" and **copy the token immediately** (you won't see it again)

### 2. Add Token to NoQCNoLife Repository

1. Go to your [NoQCNoLife repository settings](https://github.com/balcsida/NoQCNoLife/settings/secrets/actions)

2. Click "New repository secret"

3. Add the secret:
   - **Name**: `HOMEBREW_TAP_TOKEN`
   - **Secret**: Paste the token you copied
   - Click "Add secret"

### 3. Verify Setup

The next time you create a release (push a version tag), the GitHub Action will:
1. Build and release the DMG
2. Automatically update the Homebrew tap using your token
3. Users can immediately update via `brew upgrade --cask noqcnolife`

## Token Expiration

When your token expires:
1. Create a new fine-grained token following the same steps
2. Update the `HOMEBREW_TAP_TOKEN` secret with the new token
3. Delete the expired token from your GitHub settings

## Troubleshooting

### Token not working?
- Verify the token has access to `balcsida/homebrew-tap` repository
- Check that Contents permission is set to "Read and write"
- Ensure the secret name is exactly `HOMEBREW_TAP_TOKEN`

### Workflow still failing?
- Check the [Actions tab](https://github.com/balcsida/NoQCNoLife/actions) for detailed logs
- The step is set to `continue-on-error`, so it won't break releases
- You can always manually update using: `./scripts/update-homebrew-tap.sh`

## Security Best Practices

- Use fine-grained tokens instead of classic tokens
- Set reasonable expiration dates (90 days recommended)
- Only grant minimal required permissions
- Rotate tokens regularly
- Never commit tokens to code

## Manual Alternative

If you prefer not to use tokens, you can manually update after each release:
```bash
./scripts/update-homebrew-tap.sh <version> <sha256>
```

The release workflow will show the exact command with the correct values.