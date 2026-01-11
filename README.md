[![Docker Image Version](https://img.shields.io/docker/v/ls250824/run-comfyui-image)](https://hub.docker.com/r/ls250824/run-comfyui-image)

# 🚀 Run image with ComfyUI with provisioning RunPod

A streamlined and automated environment for running **ComfyUI** with **image models**, optimized for use on RunPod

## Running Flux.2 dev turbo

![runpod](images/runpod_ZIT.jpg)


![Image](images/image_ZIT.jpg)

## 🔧 Features

- Automatic model and LoRA downloads via environment variables.
- Built-in **authentication** for:
  - ComfyUI
  - Code Server
  - Hugging Face API
  - CivitAI API
- Supports advanced workflows for **image generation** and **enhancement** using pre-installed custom nodes.
- Compatible with high-performance NVIDIA GPUs.

## 🧩 Template Deployment

### Deployment

- All available templates on runpod are tested on a RTX 6000 only.

### Runpod templates

- 👉 [Runpod Z-Image Turbo](https://console.runpod.io/deploy?template=ia5t70hfak&ref=se4tkc5o)
- 👉 [Runpod Flux.2 Dev](https://console.runpod.io/deploy?template=8nl523gts5&ref=se4tkc5o)
- 👉 [Runpod Qwen image edit 2511](https://console.runpod.io/deploy?template=mxvvx0hcmp&ref=se4tkc5o)

### Documentation

- [⚙️ Start](https://awesome-comfyui.rozenlaan.site/ComfyUI_image/)
- [📚 Tutorial](https://awesome-comfyui.rozenlaan.site/ComfyUI_image_tutorial/)
- [⚙️ Provisioning examples](docs/ComfyUI_image_provisioning.md)

## 🐳 Docker Images

### Base Images

- **PyTorch Runtime**  [![Docker](https://img.shields.io/docker/v/ls250824/pytorch-cuda-ubuntu-runtime)](https://hub.docker.com/r/ls250824/pytorch-cuda-ubuntu-runtime)

- **ComfyUI Runtime**  [![Docker](https://img.shields.io/docker/v/ls250824/comfyui-runtime)](https://hub.docker.com/r/ls250824/comfyui-runtime)

### Custom Image

docker pull ls250824/run-comfyui-image:<[![Docker Image Version](https://img.shields.io/docker/v/ls250824/run-comfyui-image)](https://hub.docker.com/r/ls250824/run-comfyui-image)>

## 🛠️ Build & Push Docker Image to GHCR

Build and push the Flux.2 Turbo image to GitHub Container Registry (GHCR) using the automated build script.

### Prerequisites

1. Create GitHub Personal Access Token (PAT):
   - Go to GitHub Settings → Developer Settings → Personal Access Tokens (Classic)
   - Select scopes: `write:packages`, `read:packages`
   - Copy token (you won't see it again)

2. Store token in parent directory (`$HOME/dev/image-generation-prompt/`):
   ```bash
   # From rundpod directory
   echo "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" > ../.ghcr_token

   # Or from parent directory
   echo "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" > .ghcr_token
   ```

### Build Script: `build_ghcr.py`

Automated Docker image build and push to GitHub Container Registry.

| Argument           | Description                           | Default              |
|--------------------|---------------------------------------|----------------------|
| `--tag`            | Custom image tag                      | Auto-generated (timestamp) |
| `--no-push`        | Build only, don't push to GHCR        | Push enabled         |
| `--token-file`     | Path to GHCR token file               | Auto-finds in parent dir |
| `--registry`       | Container registry URL                | `ghcr.io`            |
| `--username`       | Registry username                     | `maroshi`            |

### Example Usage

**Quick Start (from rundpod directory):**
```bash
cd rundpod-flux2-dev-turbo

# Build and push with auto-generated tag
python build_ghcr.py --tag v1.0

# Build only (don't push) - for testing
python build_ghcr.py --no-push --tag test-build
```

**From parent directory:**
```bash
cd $HOME/dev/image-generation-prompt

# Update .ghcr_token with your actual PAT (locally only)
echo "ghp_your_actual_token_here" > .ghcr_token

# Build and push with version tag
python rundpod-flux2-dev-turbo/build_ghcr.py --tag v1.0

# Build with custom tag
python rundpod-flux2-dev-turbo/build_ghcr.py --tag latest

# Build only (don't push)
python rundpod-flux2-dev-turbo/build_ghcr.py --no-push

# Specify custom token file path
python rundpod-flux2-dev-turbo/build_ghcr.py --token-file /path/to/token
```

### Verify Image

```bash
# Check in GitHub UI
# Go to your profile → Packages → flux2-turbo-lora

# Pull and run the image
docker pull ghcr.io/maroshi/flux2-turbo-lora:v1.0
docker run -it --gpus all ghcr.io/maroshi/flux2-turbo-lora:v1.0
```

### Documentation

See [GHCR_SETUP.md](./GHCR_SETUP.md) for:
- Complete GitHub Container Registry setup guide
- Security best practices
- Troubleshooting
- Production deployment examples
