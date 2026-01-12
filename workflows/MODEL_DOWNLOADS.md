# FLUX.2 Model Downloads Configuration

## Overview

The `start.sh` script has been configured to automatically download all required FLUX.2 Dev Turbo models optimized for **48GB VRAM**.

## What Gets Downloaded

### 1. VAE (~200 MB)
- **File:** `flux2-vae.safetensors`
- **Location:** `models/vae/`
- **Source:** black-forest-labs/FLUX.2-dev (ae.safetensors)

### 2. Text Encoder BF16 (~5.6 GB)
- **File:** `mistral_3_small_flux2_bf16.safetensors`
- **Location:** `models/text_encoders/`
- **Source:** Comfy-Org/flux2-dev
- **Note:** Using BF16 for best quality (48GB VRAM allows this)

### 3. Diffusion Model FP8 (~17 GB)
- **File:** `flux2_dev_fp8mixed.safetensors`
- **Locations:**
  - `models/unet/`
  - `models/diffusion_models/` (copy for compatibility)
- **Source:** Comfy-Org/flux2-dev
- **Note:** FP8 mixed precision for optimal speed/quality balance

### 4. Turbo LoRA (~35 MB)
- **File:** `Flux2TurboComfyv2.safetensors`
- **Location:** `models/loras/`
- **Source:** ByteZSzn/Flux.2-Turbo-ComfyUI
- **Purpose:** Enables 2-8 step fast generation

## Total Storage Required

**~23 GB** total for all FLUX.2 models
- VAE: 0.2 GB
- Text Encoder: 5.6 GB
- Diffusion Model: 17 GB (stored in 2 locations)
- Turbo LoRA: 0.035 GB

## Directory Structure

```
/workspace/ComfyUI/models/
├── vae/
│   └── flux2-vae.safetensors                      [200 MB]
├── text_encoders/
│   └── mistral_3_small_flux2_bf16.safetensors     [5.6 GB]
├── unet/
│   └── flux2_dev_fp8mixed.safetensors             [17 GB]
├── diffusion_models/
│   └── flux2_dev_fp8mixed.safetensors             [17 GB copy]
└── loras/
    └── Flux2TurboComfyv2.safetensors              [35 MB]
```

## Download Behavior

### When Downloads Happen
- **Automatic:** On first container startup when models are missing
- **Skip:** If models already exist in target directories
- **Check:** Uses `find` to detect existing `.safetensors` or `.pt` files

### Download Method
1. Downloads file to HuggingFace cache first
2. Copies from cache to correct ComfyUI model directory
3. Ensures flat directory structure (no `split_files/` subdirectories)
4. Provides progress feedback in console

### Error Handling
- Each model downloads independently
- Failures are logged but don't stop other downloads
- Container continues even if some models fail to download

## Excluded Models

The following are **NOT** downloaded (as per requirements):

### ❌ FLUX.1 Models
- Not needed for FLUX.2 workflows
- Saves ~17 GB storage

### ❌ GGUF Quantized Models
- Not needed with 48GB VRAM
- Can use full precision models
- Saves 20-40 GB storage

### ❌ FP8 Text Encoder
- Using BF16 instead for better quality
- 48GB VRAM allows full precision text encoder

## Workflow Compatibility

All downloaded models are compatible with:
- ✅ flux2_turbo_2-8steps_sharcodin.json
- ✅ flux2_turbo_kombitz_6ref.json
- ✅ flux2_turbo_default.json
- ✅ flux2_example_official.png

**Note:** The following workflows require FLUX.1 models (not downloaded):
- ❌ flux_lora_xlabs.json
- ❌ flux_lora_rundiffusion.json

## Manual Download (Alternative)

If you prefer to download manually before starting:

```bash
# VAE
wget https://huggingface.co/black-forest-labs/FLUX.2-dev/resolve/main/ae.safetensors \
  -O /workspace/ComfyUI/models/vae/flux2-vae.safetensors

# Text Encoder BF16
wget https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/text_encoders/mistral_3_small_flux2_bf16.safetensors \
  -O /workspace/ComfyUI/models/text_encoders/mistral_3_small_flux2_bf16.safetensors

# Diffusion Model FP8
wget https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/diffusion_models/flux2_dev_fp8mixed.safetensors \
  -O /workspace/ComfyUI/models/unet/flux2_dev_fp8mixed.safetensors

# Turbo LoRA
wget https://huggingface.co/ByteZSzn/Flux.2-Turbo-ComfyUI/resolve/main/Flux2TurboComfyv2.safetensors \
  -O /workspace/ComfyUI/models/loras/Flux2TurboComfyv2.safetensors
```

## Verification

After container starts, check model downloads:

```bash
# Check all model directories
find /workspace/ComfyUI/models -name "*.safetensors" -type f -exec ls -lh {} \;

# Check specific models
ls -lh /workspace/ComfyUI/models/vae/flux2-vae.safetensors
ls -lh /workspace/ComfyUI/models/text_encoders/mistral_3_small_flux2_bf16.safetensors
ls -lh /workspace/ComfyUI/models/unet/flux2_dev_fp8mixed.safetensors
ls -lh /workspace/ComfyUI/models/loras/Flux2TurboComfyv2.safetensors
```

## Performance Expectations

With 48GB VRAM and these models:
- **Generation Speed:** 2-8 steps with Turbo LoRA (vs 20-50 standard)
- **Image Quality:** High quality with BF16 text encoder
- **VRAM Usage:** ~20-25GB during generation
- **Batch Size:** Can generate multiple images in parallel

## Troubleshooting

### Models Not Downloading
1. Check internet connection
2. Verify HuggingFace is accessible
3. Check logs: `docker logs <container_id>`

### Wrong Directory Structure
- Old issue: Files in `split_files/vae/` subdirectories
- Fixed: Files now copied directly to model directories

### Workflow Can't Find Models
1. Check file names match exactly
2. Verify files are in correct directories
3. Try both `unet/` and `diffusion_models/` for diffusion model

---

*Last updated: January 13, 2026*
*Optimized for 48GB VRAM - No FLUX.1, No GGUF*
