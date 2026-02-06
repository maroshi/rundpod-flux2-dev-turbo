[![Docker Image Version](https://img.shields.io/docker/v/ls250824/run-comfyui-image)](https://hub.docker.com/r/ls250824/run-comfyui-image)

# 🚀 Run image with ComfyUI with provisioning RunPod

A streamlined and automated environment for running **ComfyUI** with **image models**, optimized for use on RunPod

## Running Flux.2 dev turbo

![runpod](images/runpod_ZIT.jpg)


![Image](images/image_ZIT.jpg)

## 🔧 Features

- **Auto-load default workflow** via `DEFAULT_WORKFLOW_URL` environment variable (see [documentation](documentation/DEFAULT_WORKFLOW.md))
- **Disable authentication by default** - No login screen required (configurable via `DISABLE_AUTH` environment variable, see [security documentation](documentation/SECURITY.md))
- Automatic model and LoRA downloads via environment variables.
- Built-in **API authentication** for:
  - Code Server
  - Hugging Face API
  - CivitAI API
- Supports advanced workflows for **image generation** and **enhancement** using pre-installed custom nodes.
- Compatible with high-performance NVIDIA GPUs.

## 🎯 Model Selection

Control which FLUX.2 models are downloaded at pod startup using the `FLUX_MODEL` environment variable:

| Value | Models Loaded | Size | Startup Time | Use Case |
|-------|--------------|------|--------------|----------|
| `common` | VAE + Turbo LoRA | ~3GB | 30 sec | Testing, minimal setup |
| `klein` | Common + Klein models | ~27GB | 3-4 min | FLUX.2 Klein workflows |
| `dev` | Common + Dev models | ~54GB | 6-8 min | FLUX.2 Dev workflows |
| `all` | All models | ~76GB | 8-10 min | Full functionality |

### Quick Start

**On RunPod:**
```bash
# Set FLUX_MODEL in pod environment variables
FLUX_MODEL=klein
```

**Local Docker:**
```bash
docker run -e FLUX_MODEL=dev ghcr.io/maroshi/flux2-dev-turbo:latest
```

**Default:** If not set, defaults to `common` (VAE + Turbo LoRA only).

See [Model Selection Guide](docs/MODEL-SELECTION.md) for detailed information.

## 🐳 Docker Images

### Base Images

- **PyTorch Runtime**  [![Docker](https://img.shields.io/docker/v/ls250824/pytorch-cuda-ubuntu-runtime)](https://hub.docker.com/r/ls250824/pytorch-cuda-ubuntu-runtime)

- **ComfyUI Runtime**  [![Docker](https://img.shields.io/docker/v/ls250824/comfyui-runtime)](https://hub.docker.com/r/ls250824/comfyui-runtime)

### Custom Image

docker pull ls250824/run-comfyui-image:<[![Docker Image Version](https://img.shields.io/docker/v/ls250824/run-comfyui-image)](https://hub.docker.com/r/ls250824/run-comfyui-image)>

## 📚 Documentation

- [📖 Complete Documentation Table of Contents](documentation/MAIN.md)
- [⚙️ Provisioning examples](documentation/ComfyUI_image_provisioning.md)
- [⚙️ Start](https://awesome-comfyui.rozenlaan.site/ComfyUI_image/)
- [📚 Tutorial](https://awesome-comfyui.rozenlaan.site/ComfyUI_image_tutorial/)

## 🛠️ Build & Push Docker Image to GHCR

Build and push the Flux.2 Turbo image to GitHub Container Registry (GHCR) using the automated build script.

**⚠️ Storage Requirements:** Building this image requires approximately **30GB of free disk space**.

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

```bash
cd rundpod-flux2-dev-turbo

# Build and push with version tag
python build_ghcr.py --tag v1.0

# Build only (don't push) - for testing
python build_ghcr.py --no-push --tag test-build

# Specify custom token file path
python build_ghcr.py --token-file /path/to/token
```

### Verify Image

```bash
# Check in GitHub UI
# Go to your profile → Packages → flux2-turbo-lora

# Pull and run the image
docker pull ghcr.io/maroshi/flux2-turbo-lora:v1.0
docker run -it --gpus all ghcr.io/maroshi/flux2-turbo-lora:v1.0
```

See [documentation/GHCR_SETUP.md](documentation/GHCR_SETUP.md) for:
- Complete GitHub Container Registry setup guide
- Security best practices
- Troubleshooting
- Production deployment examples

---

## 📦 In-Container Usage Guide

This section describes how to use the container once it's running.

### Workflows

- Open from ComfyUI's interface on the left
- Download from [workflow examples](https://awesome-comfyui.rozenlaan.site/ComfyUI_image_workflows/)

### Pre-Installed Custom Nodes

- Open ComfyUI manager to view installed custom nodes
- See [documentation/MAIN.md](documentation/MAIN.md) for complete list

### Model Downloads

#### **Huggingface**

```bash
export HF_TOKEN="xxxxx"
hf download model model_name.safetensors --local-dir /workspace/ComfyUI/models/diffusion_models/
hf upload model /workspace/model.safetensors
```

```bash
hf auth login --token xxxxx
```

#### **CivitAI**

- Use terminal or ComfyUI-Lora-Manager web interface

```bash
export CIVITAI_TOKEN="xxxxx"
civitai "<download link>" /workspace/ComfyUI/models/diffusion_models
civitai "<download link>" /workspace/ComfyUI/models/loras
civitai --file batch.txt
```

### 7z Compression

#### **Encrypt & Archive Output**

```bash
7z a -p -mhe=on /workspace/output/output-image-x.7z /workspace/ComfyUI/output/
```

#### **Extract Archive**

```bash
7z x x.7z
```

### Clean up

```bash
rm -rf /workspace/output/ /workspace/input/ /workspace/ComfyUI/output/ /workspace/ComfyUI/models/loras/
ncdu
```

### Utilities

```bash
nvtop      # GPU Monitoring
nvidia-smi # GPU information
htop       # Process Monitoring
mc         # Midnight Commander (file manager)
nano       # Text Editor
ncdu       # Clean Up
unzip      # uncompress
7z         # Archiving
runpodctl  # runpod pod management
```

### Comfy-cli

```bash
comfy-cli set-default /workspace/ComfyUI/
comfy-cli
comfy-cli env
```

### Test/Debug

```bash
python /workspace/test/test_pytorch_cuda.py
python /workspace/test/test_flash.py
python /workspace/test/test_sage.py
python /workspace/test/test_torch_generic_nms.py
python /workspace/test/test_llmama_cpp.py
python /workspace/test/test_environment.py
python /workspace/test/test_environment_runpod.py
```

---

## 📚 Complete Documentation

For detailed guides, API references, and model provisioning instructions, see:

- [📖 Complete Documentation Table of Contents](documentation/MAIN.md)
- [Model Provisioning Guide](documentation/ComfyUI_image_provisioning.md)
- [Flux.2 Turbo LoRA Setup](documentation/FLUX2_TURBO_LORA_SETUP.md)
- [REST API Guide](documentation/REST_API_GUIDE.md)
- [GitHub Container Registry Setup](documentation/GHCR_SETUP.md)
