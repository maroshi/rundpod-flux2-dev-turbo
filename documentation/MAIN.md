# 📚 RunPod Flux.2 Dev Turbo - Complete Documentation

**Version:** 1.0.0-flux2-turbo-lora
**Last Updated:** January 2026
**Status:** Production Ready

---

## 📖 Table of Contents

### 🚀 Getting Started

1. [Quick Start Guide](#quick-start-guide)
2. [Docker Image Information](#docker-image-information)
3. [Deployment Options](#deployment-options)

### ⚙️ Setup & Configuration

1. **[Flux.2 Turbo LoRA Setup](FLUX2_TURBO_LORA_SETUP.md)** ⭐
   Complete guide for running Flux.2 Dev Turbo LoRA with Docker
   - Dockerfile enhancements and custom nodes
   - Model download instructions (checkpoint, text encoder, VAE, LoRA)
   - ComfyUI workflow configuration
   - Recommended settings by GPU (RTX 4090, 4080, 3060)
   - Performance benchmarks
   - Troubleshooting guide

2. **[Flux.2 Turbo Workflows & REST API Setup](FLUX2_TURBO_WORKFLOWS_API_SETUP.md)**
   Pre-configured workflows and REST API automation
   - Default Flux.2 Turbo workflow structure
   - REST API quick start guide
   - Batch processing examples
   - Docker Compose production setup
   - Performance tuning by GPU
   - Workflow customization guide

3. **[GitHub Container Registry (GHCR) Setup](GHCR_SETUP.md)**
   Build and push Docker images to GHCR
   - Personal Access Token (PAT) creation
   - Token file setup and security
   - Automated build script (`build_ghcr.py`)
   - Manual build and push instructions
   - Troubleshooting authentication issues
   - Production deployment examples

### 🔌 REST API Documentation

1. **[REST API Complete Guide](REST_API_GUIDE.md)**
   HTTP endpoints for automation and integration
   - API endpoint reference (generate, status, queue, image download)
   - Request/response examples
   - Python, JavaScript/Node.js, and Bash client examples
   - Environment variables configuration
   - Docker Compose setup with API
   - Nginx reverse proxy configuration
   - Performance optimization by GPU
   - Error handling and troubleshooting

### 🎨 Model Provisioning

1. **[Model Provisioning Index](ComfyUI_image_provisioning.md)**
   Overview of all available image generation models
   - Flux.1 variants (Dev, Kontext, SRPO, USO)
   - Flux.2 variants (Dev, Dev Turbo LoRA) ⭐
   - Z-Image Turbo
   - Qwen Image Edit variants
   - HunyuanImage 2.1
   - Chroma1 Radiance
   - Ovis
   - Segmentation, Upscaling, VLM models

2. **Detailed Provisioning Guides** (in `provisioning/` directory)
   - [Flux.2 Dev Turbo LoRA](provisioning/hf_flux.2_turbo_lora.md) ⭐ **Recommended**
   - [Flux.2 Dev](provisioning/hf_flux.2_dev.md)
   - [Flux.1 Dev](provisioning/hf_flux.1_dev.md)
   - [Flux.1 Kontext](provisioning/hf_flux.1_kontext.md)
   - [Flux.1 SRPO](provisioning/hf_flux.1_SRPO.md)
   - [Flux.1 USO](provisioning/hf_flux.1_USO.md)
   - [Z-Image Turbo](provisioning/hf_Z-image-turbo.md)
   - [Qwen Image Edit 2511](provisioning/hf_qwen-image-edit-2511.md)
   - [Qwen Image Layered](provisioning/hf_qwen-image-layered.md)
   - [HunyuanImage 2.1](provisioning/hf_hunyuan_image21.md)
   - [Chroma1 Radiance](provisioning/hf_chroma1_radiance.md)
   - [Ovis](provisioning/hf_ovis.md)
   - [Segmentation Models](provisioning/hf_segmentation.md)
   - [Upscale Models](provisioning/hf_upscale.md)
   - [VLM Tagging & Caption](provisioning/hf_vlm.md)

### 🐳 Deployment & Infrastructure

1. **[RunPod Docker Deployment](README_docker_runpod.md)**
   RunPod template deployment guide
   - Features and authentication
   - Template deployment links (Z-Image Turbo, Flux.2 Dev, Qwen)
   - Hardware and storage requirements
   - Workflow examples

2. **[RunPod Environment Templates](runpod-env-templates.md)**
   Environment variable configurations
   - Flux.2 Dev templates (public/private)
   - Z-Image-Turbo templates
   - Flux.1 variants (Kontext, SRPO)
   - Qwen-Image-Edit templates
   - Qwen-Image-Layered templates

3. **[General Pod Documentation](README.md)**
   Pod usage, utilities, and testing
   - Pre-installed custom nodes
   - HuggingFace and CivitAI setup
   - 7z compression for outputs
   - Utility commands (nvtop, htop, mc, ncdu)
   - Comfy-cli usage
   - Test/debug scripts

---

## 🎯 Quick Start Guide

### 1. Pull and Run Docker Image

```bash
# Pull the latest image
docker pull ls250824/run-comfyui-image:latest

# Run with GPU support
docker run --gpus all -it \
  -p 8188:8188 \
  -p 9000:9000 \
  -e PASSWORD="your_password" \
  -e HF_TOKEN="your_huggingface_token" \
  -v /local/workspace:/workspace \
  ls250824/run-comfyui-image:latest
```

### 2. Download Flux.2 Turbo LoRA Models

```bash
# Inside the container
huggingface-cli login

# Download checkpoint (FP8 quantized - recommended)
hf download Comfy-Org/flux2-dev split_files/diffusion_models/flux2_dev_fp8mixed.safetensors \
  --local-dir /workspace/ComfyUI/models/checkpoints/

# Download text encoder
hf download Comfy-Org/flux2-dev split_files/text_encoders/mistral_3_small_flux2_bf16.safetensors \
  --local-dir /workspace/ComfyUI/models/text_encoders/

# Download VAE
hf download Comfy-Org/flux2-dev split_files/vae/flux2-vae.safetensors \
  --local-dir /workspace/ComfyUI/models/vae/

# Download LoRA
hf download ByteZSzn/Flux.2-Turbo-ComfyUI Flux2TurboComfyv2.safetensors \
  --local-dir /workspace/ComfyUI/models/loras/
```

### 3. Access Services

- **ComfyUI Web UI**: http://localhost:8188
- **Code-Server IDE**: http://localhost:9000
- **REST API**: http://localhost:5000 (if started with `start-with-api.sh`)

### 4. Generate Images

**Via ComfyUI Web UI:**
1. Load default workflow: `workflows/flux2_turbo_default.json`
2. Set your prompt
3. Click "Queue Prompt"

**Via REST API:**
```bash
curl -X POST http://localhost:5000/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "a beautiful sunset landscape",
    "steps": 25,
    "cfg": 3.5,
    "width": 1024,
    "height": 1024
  }'
```

---

## 🐳 Docker Image Information

### Base Images

- **PyTorch Runtime**: `ls250824/pytorch-cuda-ubuntu-runtime`
- **ComfyUI Runtime**: `ls250824/comfyui-runtime:07012026`

### Custom Image

```bash
docker pull ls250824/run-comfyui-image:latest
```

**Image Features:**
- ComfyUI 0.7.0 with 45+ custom nodes pre-installed
- CUDA 12.x GPU support
- Flux.2 Dev Turbo LoRA optimized
- Background removal (RMBG), segmentation (SAM2/SAM3)
- Upscaling (Ultimate SD Upscale, RealESRGAN)
- LoRA Manager, GGUF support
- Code-Server web IDE
- REST API automation support

---

## 📊 Deployment Options

### RunPod Templates

Pre-configured RunPod templates with automatic provisioning:

- 👉 [Runpod Z-Image Turbo](https://console.runpod.io/deploy?template=ia5t70hfak&ref=se4tkc5o)
- 👉 [Runpod Flux.2 Dev](https://console.runpod.io/deploy?template=8nl523gts5&ref=se4tkc5o)
- 👉 [Runpod Qwen Image Edit 2511](https://console.runpod.io/deploy?template=mxvvx0hcmp&ref=se4tkc5o)

### Local Docker

See [Flux.2 Turbo LoRA Setup](FLUX2_TURBO_LORA_SETUP.md) for local Docker deployment.

### GitHub Container Registry (GHCR)

Build and push custom images to GHCR:

```bash
# From rundpod directory
python build_ghcr.py --tag v1.0
```

See [GHCR Setup Guide](GHCR_SETUP.md) for complete instructions.

---

## 🛠️ Key Features

### Pre-Installed Custom Nodes (45+)

**LoRA & Model Management:**
- ComfyUI-Lora-Manager
- ComfyUI-GGUF
- comfyui-model-linker-desktop

**Flux Enhancements:**
- rgthree-comfy
- KJNodes
- LG_SamplingUtils
- Power-Flow

**Image Processing:**
- Image-Saver
- EasyColorCorrector
- Detail-Daemon
- cg-image-filter

**Advanced Features:**
- RMBG (background removal)
- SAM2/SAM3 (segmentation)
- ControlNet
- Ultimate SD Upscale
- JoyCaption

### Built-in Authentication

- ComfyUI web interface
- Code-Server IDE
- HuggingFace API integration
- CivitAI API integration

### GPU Support

Optimized for NVIDIA GPUs:
- RTX 4090 (24GB) - Full resolution 1024x1024
- RTX 4080 (16GB) - 768x768 recommended
- RTX 3060 (12GB) - 512x512 recommended

---

## 📈 Performance Benchmarks

### Flux.2 Turbo LoRA Inference Times

| GPU           | VRAM  | Resolution | Steps | Time per Image |
|---------------|-------|------------|-------|----------------|
| RTX 4090      | 24GB  | 1024x1024  | 25    | 3-4 seconds    |
| RTX 4080      | 16GB  | 768x768    | 20    | 4-6 seconds    |
| RTX 3090      | 24GB  | 512x768    | 20    | 5-7 seconds    |

*Using FP8 mixed precision checkpoint and Flux.2 Turbo LoRA*

---

## 🔧 Environment Variables

| Variable               | Purpose                         | Example                   |
|------------------------|---------------------------------|---------------------------|
| `PASSWORD`             | Code-Server authentication      | `mySecurePassword123`     |
| `HF_TOKEN`             | HuggingFace API token           | `hf_xxxxxxxxxxxx`         |
| `CIVITAI_API_KEY`      | CivitAI API key                 | `xxxxx-xxxxx-xxxxx`       |
| `COMFYUI_VRAM_MODE`    | ComfyUI VRAM mode               | `HIGH_VRAM`               |
| `PYTORCH_ALLOC_CONF`   | PyTorch VRAM optimization       | `expandable_segments:True`|

See [RunPod Environment Templates](runpod-env-templates.md) for model-specific configurations.

---

## 🚨 Troubleshooting

### Common Issues

**Models Won't Load:**
1. Verify files are in correct directories
2. Check file names match exactly (case-sensitive)
3. In ComfyUI, go to Manager > Refresh

**Out of Memory (OOM):**
- Use FP8 quantized models
- Reduce batch size to 1
- Use lower resolution
- Enable VRAM optimization

**Slow Inference:**
- Use single LoRA (multiple LoRAs slow down significantly)
- Reduce step count (20-24 sufficient for Turbo)
- Lower resolution

**CUDA Not Detected:**
1. Verify drivers: `nvidia-smi`
2. Check PyTorch: `python -c "import torch; print(torch.cuda.is_available())"`
3. Restart container

---

## 📞 Support & Resources

### Documentation

- **Main Repository**: [maroshi/rundpod-flux2-dev-turbo](https://github.com/maroshi/rundpod-flux2-dev-turbo)
- **ComfyUI Docs**: https://docs.comfy.org
- **Awesome ComfyUI**: https://awesome-comfyui.rozenlaan.site/

### Issues & Questions

- GitHub Issues: [rundpod-flux2-dev-turbo/issues](https://github.com/maroshi/rundpod-flux2-dev-turbo/issues)
- ComfyUI Community: https://comfyanonymous.github.io/ComfyUI_examples/

---

## 📝 License & Attribution

- **ComfyUI**: MIT License
- **Flux.2 Models**: Black Forest Labs
- **Custom Nodes**: Various authors (see individual node repositories)
- **This Image**: MIT License

---

**Built with ❤️ by the ComfyUI Community**
