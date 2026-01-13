# Security Configuration

This document explains the security settings in ComfyUI and how to configure authentication.

## Authentication Control

### Disabling Login Screen

By default, this image **disables authentication** for easier access. The login screen is removed automatically on startup.

To **enable authentication**, set this environment variable in your RunPod template:

```bash
DISABLE_AUTH=false
```

**Default behavior:**
- `DISABLE_AUTH=true` (default) - No login required, authentication custom nodes are removed
- `DISABLE_AUTH=false` - Enables login screen (if ComfyUI-Login is installed in base image)

### How It Works

The startup script removes these authentication custom nodes:
- `ComfyUI-Login`
- `ComfyUI-Basic-Auth`
- `comfyui-basic-auth`

**Note:** ComfyUI core does NOT have built-in authentication. Login screens come from third-party custom nodes.

## ComfyUI-Manager Security Levels

The `security_level` setting in `configuration/config.ini` controls what operations are allowed in ComfyUI-Manager. **This is unrelated to login screens.**

### Security Level Values

| Level | Description | What It Allows |
|-------|-------------|----------------|
| `strong` | Most restrictive | ComfyUI updates only, blocks all other installations |
| `normal` | Default (recommended) | Install/update registered nodes, blocks unverified Git repos and pip installs |
| `normal-` | Developer mode | All `normal` operations + Git URL/pip installs (localhost only) |
| `weak` | Least restrictive | All operations allowed, including high-risk features from remote |

### Current Configuration

```ini
security_level = normal
network_mode = personal_cloud
```

### What Each Level Controls

**`strong`** (Most Restrictive)
- ✅ ComfyUI core updates
- ❌ Custom node installations
- ❌ Git URL installations
- ❌ pip installs
- ❌ "Try fix" feature

**`normal`** (Default - Recommended)
- ✅ Install/update/remove registered custom nodes
- ✅ Install registered models
- ❌ Unverified Git repository installations
- ❌ pip installs from web UI
- ❌ "Try fix" feature

**`normal-`** (Developer Mode)
- ✅ All `normal` operations
- ✅ Install via Git URL (localhost only)
- ✅ pip installs (localhost only)
- ✅ Works only when server runs on 127.x.x.x

**`weak`** (Least Restrictive)
- ✅ All operations allowed
- ✅ Install plugins from any source
- ✅ High-risk and middle-risk features
- ✅ Works even from remote connections

### Risky Features Classification

**High-risk features:**
- Install via git URL
- pip install operations
- Install custom nodes not registered in default channel
- "Try fix" feature for broken custom nodes

**Middle-risk features:**
- Custom node updates
- Snapshot operations
- ComfyUI restarts

### Network Mode

The `network_mode` setting works with `security_level`:

| Mode | Description |
|------|-------------|
| `public` | Standard public server mode |
| `private` | Private network mode |
| `offline` | No network operations |
| `personal_cloud` | Default - allows certain operations with appropriate security level |

## Important Distinctions

### Authentication vs. Security Level

**Authentication (Login Screen)**
- Controlled by: `DISABLE_AUTH` environment variable
- Purpose: User login and password protection
- Default: **Disabled** in this image
- Provided by: Third-party custom nodes (ComfyUI-Login, etc.)

**Security Level**
- Controlled by: `security_level` in `config.ini`
- Purpose: Controls what operations are allowed (installs, updates, etc.)
- Default: `normal`
- Provided by: ComfyUI-Manager

**These are completely separate systems!** Changing `security_level` does NOT affect login screens.

## Recommendations

### For Development/Personal Use
```bash
# In RunPod template
DISABLE_AUTH=true          # No login required
security_level=normal-     # Allow git installs on localhost
```

### For Public Deployment
```bash
# In RunPod template
DISABLE_AUTH=false         # Require login
security_level=strong      # Block risky operations
```

### For Team/Shared Environment
```bash
# In RunPod template
DISABLE_AUTH=false         # Require login
security_level=normal      # Allow registered nodes only
network_mode=private       # Private network mode
```

## References

- [ComfyUI-Manager Security Documentation](https://comfyui-wiki.com/en/faq/fix-comfyui-manager-security-level-error)
- [ComfyUI-Login Custom Node](https://github.com/liusida/ComfyUI-Login)
- [ComfyUI Authentication Discussion](https://github.com/comfyanonymous/ComfyUI/discussions/5165)
