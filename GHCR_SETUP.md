# GitHub Container Registry (GHCR) Setup Guide

Complete guide for setting up GitHub Container Registry (GHCR) authentication and pushing Docker images from the Flux.2 Turbo repository.

## Overview

GitHub Container Registry (GHCR) is a container registry hosted by GitHub. It allows you to store and manage Docker images privately or publicly associated with your GitHub account.

**Registry URL**: `ghcr.io`
**Format**: `ghcr.io/username/imagename:tag`
**Example**: `ghcr.io/maroshi/flux2-turbo-lora:latest`

## Prerequisites

- GitHub account with push access to `https://github.com/maroshi/`
- Docker installed locally
- Personal Access Token (PAT) with `write:packages` scope

## Step 1: Create a Personal Access Token (PAT)

A PAT is required to authenticate with GHCR. This is more secure than using your GitHub password.

### Via GitHub Web UI

1. Go to **GitHub Settings** → **Developer Settings** → **Personal Access Tokens (Classic)**
   - URL: https://github.com/settings/tokens

2. Click **"Generate new token (classic)"**

3. Fill in token details:
   - **Note**: `GHCR Docker Push - Flux.2 Turbo Image` (or similar description)
   - **Expiration**: 30 days (recommended for security)
   - **Scopes**: Select the following:
     - ✅ `write:packages` - Upload packages to GitHub Package Registry
     - ✅ `read:packages` - Download packages from GitHub Package Registry

4. Click **"Generate token"**

5. **IMPORTANT**: Copy the token immediately - you won't see it again!
   - Format: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - Store securely (password manager, local env file, etc.)

## Step 2: Create Token File in Parent Directory

Create `.ghcr_token` file in the parent directory. This file is committed to the private repository.

### Setup Token File

```bash
# Navigate to parent directory
cd $HOME/dev/image-generation-prompt

# Create token file with your PAT
echo "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" > .ghcr_token

# Verify it's readable
cat .ghcr_token
```

### Using Custom Token File Path

If you want to store the token elsewhere:

```bash
# Use custom path argument
python build_ghcr.py --token-file /path/to/my/token --tag v1.0
```

### Token File Security

- ✅ `.ghcr_token` is committed to private repository
- ✅ Default location: parent directory (`../.ghcr_token`)
- ✅ Can override with `--token-file` argument
- ⚠️ Keep actual PAT secret - use placeholder during initial commit if needed
- ⚠️ Update file with actual token locally before running build script

## Step 3: Build and Push Docker Image

### Using Automated Build Script (Recommended)

The `build_ghcr.py` script in the parent directory automatically:
- Finds your token file in standard locations
- Authenticates with GHCR
- Builds the Docker image
- Pushes to GHCR with optional version tagging

```bash
# Navigate to parent directory
cd $HOME/dev/image-generation-prompt/

# Build with auto-generated tag
python build_ghcr.py

# Build with version tag
python build_ghcr.py --tag v1.0

# Build with custom tag
python build_ghcr.py --tag latest

# Build only, don't push
python build_ghcr.py --no-push

# Use custom token file path
python build_ghcr.py --token-file /path/to/token
```

**Script Behavior**:
- Looks for `.ghcr_token` in parent directory (default location)
- Can override token file path via `--token-file` argument
- Reads token from file and authenticates with GHCR
- Builds image from `rundpod-flux2-dev-turbo/Dockerfile`
- Pushes with both version tag and `latest` tag
- Colored output with clear progress logging

### Manual Build and Push

If you prefer to build and push manually:

```bash
# Read token from parent directory
cd $HOME/dev/image-generation-prompt
TOKEN=$(cat .ghcr_token)

# Authenticate with GHCR
echo "$TOKEN" | docker login ghcr.io -u maroshi --password-stdin

# Navigate to Flux.2 repo
cd rundpod-flux2-dev-turbo

# Build the image
docker build -t ghcr.io/maroshi/flux2-turbo-lora:v1.0 .

# Push to GHCR
docker push ghcr.io/maroshi/flux2-turbo-lora:v1.0

# Also push as latest
docker tag ghcr.io/maroshi/flux2-turbo-lora:v1.0 ghcr.io/maroshi/flux2-turbo-lora:latest
docker push ghcr.io/maroshi/flux2-turbo-lora:latest
```

## Step 4: Verify Push and Access

### Check in GitHub UI

1. Go to your GitHub profile → **Packages**
2. Look for `flux2-turbo-lora` package
3. View image details and available tags

### Pull Image Locally

```bash
# Authenticate (if not already logged in)
echo "YOUR_PAT_TOKEN" | docker login ghcr.io -u maroshi --password-stdin

# Pull the image
docker pull ghcr.io/maroshi/flux2-turbo-lora:latest

# Run a container
docker run -it --gpus all ghcr.io/maroshi/flux2-turbo-lora:latest
```

## Security Best Practices

### Token Management

- ❌ **Never commit PAT tokens to Git** (use `.gitignore`)
- ❌ **Never share PAT tokens in plain text**
- ❌ **Never use a PAT without expiration in production**
- ✅ **Store token in file with restricted permissions (600)**
- ✅ **Use short expiration dates (30 days recommended)**

### Recommended Practices

1. **Token File in Repository**
   - Store token in `.ghcr_token` in parent directory (committed to repo)
   - Use placeholder PAT during initial setup: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - Replace with actual token locally before running build script
   - Never push actual token to remote (update locally only)

2. **Use Short Expiration**
   - Set PAT to expire in 30-90 days
   - Regenerate regularly and update `.ghcr_token`

3. **Limit Scopes**
   - Only grant `write:packages` and `read:packages`
   - Don't grant unnecessary permissions

4. **Use Separate Tokens for Different Purposes**
   - Development token: 30-day expiration
   - CI/CD token: 90-day expiration
   - Rotate regularly

5. **Audit and Revoke**
   - Regularly check GitHub Settings → Developer Settings → Personal Access Tokens
   - Revoke unused or compromised tokens immediately

### Token File Setup (Parent Directory)

```bash
# Create token file in parent directory with placeholder
cd $HOME/dev/image-generation-prompt
echo "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" > .ghcr_token

# Verify it's readable
cat .ghcr_token

# Commit to repository
git add .ghcr_token
git commit -m "chore: Add GHCR token file template"
```

### Update Token Locally (Before Running Build)

```bash
# Update .ghcr_token with your actual PAT (locally only)
cd $HOME/dev/image-generation-prompt
echo "ghp_your_actual_token_here" > .ghcr_token

# Verify content
cat .ghcr_token

# DO NOT commit the actual token
git checkout .ghcr_token  # Revert to placeholder before pushing
```

## Troubleshooting

### Token File Not Found

**Problem**: "GHCR token file not found" when running build script.

**Solution**:
```bash
# Create token file in parent directory with placeholder
cd $HOME/dev/image-generation-prompt
echo "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" > .ghcr_token

# Verify it's readable
cat .ghcr_token
```

Script searches in order:
1. `.ghcr_token` (parent directory - DEFAULT)
2. Custom path via `--token-file` argument (if provided)

### "unauthorized: authentication required"

**Problem**: Docker cannot authenticate with GHCR.

**Solution**:
```bash
# Verify token file exists and is readable
cat .ghcr_token

# Update with actual token if using placeholder
echo "ghp_your_actual_token_here" > .ghcr_token

# Re-authenticate
TOKEN=$(cat .ghcr_token)
echo "$TOKEN" | docker login ghcr.io -u maroshi --password-stdin

# Verify login succeeded
docker info | grep -i registry
```

### "denied: installation resource forbidden"

**Problem**: Your PAT doesn't have `write:packages` scope.

**Solution**:
1. Go to GitHub Settings → Developer Settings → Personal Access Tokens (Classic)
2. Edit the token that's in `.ghcr_token`
3. Ensure `write:packages` is checked
4. Save changes
5. Update token in file: `echo "new_token" > .ghcr_token` (locally only)
6. Re-run build script

### "name unknown: repository not found"

**Problem**: Image name is incorrect or not properly tagged.

**Solution**:
```bash
# Correct format: ghcr.io/username/imagename:tag
# Build with version tag
python build_ghcr.py --tag v1.0

# Or manually
docker build -t ghcr.io/maroshi/flux2-turbo-lora:v1.0 rundpod-flux2-dev-turbo
docker push ghcr.io/maroshi/flux2-turbo-lora:v1.0
```

### Token Expired

**Problem**: "denied: authentication required" after 30 days.

**Solution**:
1. Generate a new PAT in GitHub Settings → Personal Access Tokens
2. Update token file: `echo "new_token" > .ghcr_token` (locally only)
3. Re-run build script
4. Revoke the old expired token in GitHub Settings

### Build Script Says "Token File Not Found"

**Problem**: Script cannot find `.ghcr_token` in parent directory.

**Solution**:
```bash
# Check if file exists in parent directory
cd $HOME/dev/image-generation-prompt/rundpod-flux2-dev-turbo
ls -la .ghcr_token

# If not, create it with placeholder
echo "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" > .ghcr_token

# Then update with actual token locally
echo "ghp_your_actual_token_here" > .ghcr_token

# Verify it's readable
cat .ghcr_token

# Or specify explicit path via --token-file
python build_ghcr.py --token-file /path/to/my/token/file
```

## Using GHCR Images in Production

### Docker Compose with GHCR Image

```yaml
version: '3.8'

services:
  flux2-turbo:
    image: ghcr.io/maroshi/flux2-turbo-lora:latest
    container_name: flux2-turbo-prod
    ports:
      - "8188:8188"
      - "5000:5000"
    volumes:
      - workspace:/workspace
    environment:
      COMFYUI_VRAM_MODE: HIGH_VRAM
    restart: unless-stopped

  # Authentication secret (add to .env file)

volumes:
  workspace:
```


## References

- [GitHub Docs: Working with the Container registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [GitHub Docs: Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
- [Docker: Authenticate with GitHub Packages](https://docs.docker.com/docker-hub/github-integration/)

## Related Documentation

- **Flux.2 Turbo Setup**: See `rundpod-flux2-dev-turbo/FLUX2_TURBO_WORKFLOWS_API_SETUP.md`
- **REST API Guide**: See `rundpod-flux2-dev-turbo/docs/REST_API_GUIDE.md`
- **LoRA Setup**: See `rundpod-flux2-dev-turbo/docs/provisioning/hf_flux.2_turbo_lora.md`

---

**Last Updated**: January 2026
**Status**: Production Ready
**Version**: 1.0.0-ghcr-setup
