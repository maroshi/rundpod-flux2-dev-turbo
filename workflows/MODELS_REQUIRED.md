# Required Models for FLUX.2 Workflows

This document lists all models required by the FLUX.2 workflows in this directory.

## 🎯 Summary

All FLUX.2 workflows use the **same core models** (auto-downloaded by start.sh):
- **Diffusion Model:** flux2_dev_fp8mixed.safetensors (~34GB FP8)
- **Text Encoder:** mistral_3_small_flux2_bf16.safetensors (~34GB BF16)
- **VAE:** flux2-vae.safetensors (~321MB)
- **Turbo LoRA:** Flux2TurboComfyv2.safetensors (~2.6GB)

**Total Storage:** ~70GB for all FLUX.2 models

---

## 📦 Core Models (Auto-Downloaded)

These models are automatically downloaded on first container startup:

### 1. Diffusion Model (UNET)
- **File:** `flux2_dev_fp8mixed.safetensors`
- **Size:** ~34GB
- **Precision:** FP8 mixed (optimal speed/quality)
- **Location:** `/workspace/ComfyUI/models/unet/`
- **Source:** [Comfy-Org/flux2-dev](https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/diffusion_models/flux2_dev_fp8mixed.safetensors)

### 2. Text Encoder (CLIP)
- **File:** `mistral_3_small_flux2_bf16.safetensors`
- **Size:** ~34GB
- **Precision:** BF16 (best quality)
- **Location:** `/workspace/ComfyUI/models/clip/`
- **Source:** [Comfy-Org/flux2-dev](https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/text_encoders/mistral_3_small_flux2_bf16.safetensors)
- **Note:** FLUX.2 uses single Mistral-3-Small encoder (NOT T5-XXL + CLIP-L like FLUX.1)

### 3. VAE
- **File:** `flux2-vae.safetensors`
- **Size:** ~321MB
- **Location:** `/workspace/ComfyUI/models/vae/`
- **Source:** [Comfy-Org/flux2-dev](https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors)

### 4. Turbo LoRA
- **File:** `Flux2TurboComfyv2.safetensors`
- **Size:** ~2.6GB
- **Location:** `/workspace/ComfyUI/models/loras/`
- **Source:** [ByteZSzn/Flux.2-Turbo-ComfyUI](https://huggingface.co/ByteZSzn/Flux.2-Turbo-ComfyUI/resolve/main/Flux2TurboComfyv2.safetensors)
- **Purpose:** Enables 2-8 step fast generation (vs 20-50 steps standard)

---

## 📋 Workflow-Specific Requirements

### 1. flux2_turbo_default.json ⭐
**Type:** Simple 4-step FLUX.2 Turbo workflow

**Required Models:**
- ✅ Diffusion Model: `flux2_dev_fp8mixed.safetensors`
- ✅ Text Encoder: `mistral_3_small_flux2_bf16.safetensors`
- ✅ VAE: `flux2-vae.safetensors`
- ✅ Turbo LoRA: `Flux2TurboComfyv2.safetensors`

**Settings:**
- Steps: 4 (Turbo optimized)
- CFG: 1.0
- Resolution: 1024×1024
- Sampler: euler, simple scheduler

**Notes:**
- Includes built-in documentation nodes
- Best for beginners and fast generation
- ~6s per image on RTX 3090

---

### 2. flux2_turbo_2-8steps_sharcodin.json
**Type:** Advanced 2-8 step FLUX.2 Turbo workflow

**Required Models:**
- ✅ Diffusion Model: `flux2_dev_fp8mixed.safetensors` → `models/diffusion_models/` or `models/unet/`
- ✅ Text Encoder: `mistral_3_small_flux2_bf16.safetensors` → `models/text_encoders/` or `models/clip/`
- ✅ VAE: `flux2-vae.safetensors` → `models/vae/`
- ✅ Turbo LoRA: `Flux2TurboComfyv2.safetensors` → `models/loras/`

**Optional Models:**
- GGUF Diffusion: For quantized models (lower VRAM)
- GGUF Text Encoder: For quantized text encoding

**Settings:**
- Steps: 2-8 (default: 2)
- Guidance: 4.0 (FluxGuidance)
- Resolution: 1088×1920 (ultrawide, variable)
- Sampler: SamplerCustomAdvanced with Flux2Scheduler

**Notes:**
- Uses resolution-aware custom scheduler
- Supports GGUF quantized models
- More complex workflow structure

---

### 3. flux2_turbo_kombitz_6ref.json
**Type:** FLUX.2 Turbo with 6 reference images

**Required Models:**
- ✅ Diffusion Model: `flux2_dev_fp8mixed.safetensors`
- ✅ Text Encoder: `mistral_3_small_flux2_bf16.safetensors`
- ✅ VAE: `flux2-vae.safetensors`
- ✅ Turbo LoRA: `Flux2TurboComfyv2.safetensors`

**Settings:**
- Steps: 8 (default)
- Resolution: 1088×1920 (variable)
- Sampler: SamplerCustomAdvanced
- Reference images: 6 simultaneous

**Notes:**
- Includes 6 reference image subgraphs
- For style transfer and visual guidance
- Professional production workflow

---

### 4. flux2_example_official.png
**Type:** Official ComfyUI FLUX.2 example

**Required Models:**
- ✅ Same as all other FLUX.2 workflows
- Embedded workflow can be extracted by dragging PNG into ComfyUI

---

## 🚫 FLUX.1 Workflows Removed

The following FLUX.1 workflows have been **removed** due to incompatibility:

### ❌ flux_lora_xlabs.json (Removed)
**Why removed:**
- Required FLUX.1 model: `flux1-dev-fp8.safetensors`
- Required FLUX.1 text encoders: `clip_l.safetensors` + `t5xxl_fp16.safetensors`
- Used `DualCLIPLoader` (not compatible with FLUX.2)
- FLUX.1 architecture incompatible with FLUX.2

### ❌ flux_lora_rundiffusion.json (Removed)
**Why removed:**
- Required FLUX.1 model: `flux-1-dev-fp8.safetensors`
- Required FLUX.1 text encoders: `t5xxl_fp8_e4m3fn.safetensors` + `clip_l.safetensors`
- Used `DualCLIPLoader` (not compatible with FLUX.2)
- FLUX.1 architecture incompatible with FLUX.2

**FLUX.1 vs FLUX.2 Key Differences:**
- **FLUX.1:** Dual text encoders (T5-XXL 4.7GB + CLIP-L 246MB) = Total 5GB
- **FLUX.2:** Single text encoder (Mistral-3-Small 34GB)
- **Result:** Different node types, incompatible LoRAs, different model files

---

## 📂 Model Directory Structure

After auto-download, your directory structure will be:

```
/workspace/ComfyUI/models/
├── unet/
│   └── flux2_dev_fp8mixed.safetensors          [~34GB]
├── clip/
│   └── mistral_3_small_flux2_bf16.safetensors  [~34GB]
├── vae/
│   └── flux2-vae.safetensors                   [~321MB]
└── loras/
    └── Flux2TurboComfyv2.safetensors           [~2.6GB]
```

**Note:** Some workflows may look for models in alternate directories:
- `models/diffusion_models/` (alias for `models/unet/`)
- `models/text_encoders/` (alias for `models/clip/`)

The start.sh script handles these directory variations automatically.

---

## 🔄 Automatic Download via start.sh

**All models auto-download on first container startup!**

The `start.sh` script:
1. Checks if models exist in target directories
2. Downloads missing models from HuggingFace (public repos)
3. Places models in correct ComfyUI directories
4. Verifies download success
5. Continues even if some downloads fail

**No manual intervention required!**

See `MODEL_DOWNLOADS.md` for detailed download process.

---

## 💾 Storage Requirements

### FLUX.2 Complete Setup
- **Total:** ~70GB
  - Diffusion Model (FP8): 34GB
  - Text Encoder (BF16): 34GB
  - VAE: 321MB
  - Turbo LoRA: 2.6GB

### VRAM Requirements
- **Minimum:** 24GB VRAM (with FP8 models)
- **Recommended:** 48GB VRAM (for BF16 text encoder)
- **Optimal:** 80GB VRAM (for batch processing)

### Disk Space
- **Minimum:** 80GB free (models + system)
- **Recommended:** 120GB free (models + generated images)

---

## 📥 Manual Download (Alternative)

If you prefer to pre-download models:

```bash
# Create directories
mkdir -p /workspace/ComfyUI/models/{unet,clip,vae,loras}

# Diffusion Model (~34GB)
wget https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/diffusion_models/flux2_dev_fp8mixed.safetensors \
  -O /workspace/ComfyUI/models/unet/flux2_dev_fp8mixed.safetensors

# Text Encoder (~34GB)
wget https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/text_encoders/mistral_3_small_flux2_bf16.safetensors \
  -O /workspace/ComfyUI/models/clip/mistral_3_small_flux2_bf16.safetensors

# VAE (~321MB)
wget https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors \
  -O /workspace/ComfyUI/models/vae/flux2-vae.safetensors

# Turbo LoRA (~2.6GB)
wget https://huggingface.co/ByteZSzn/Flux.2-Turbo-ComfyUI/resolve/main/Flux2TurboComfyv2.safetensors \
  -O /workspace/ComfyUI/models/loras/Flux2TurboComfyv2.safetensors
```

---

## ✅ Verification

After models download, verify with:

```bash
# Check all models
find /workspace/ComfyUI/models -name "*.safetensors" -type f -exec ls -lh {} \;

# Check specific files
ls -lh /workspace/ComfyUI/models/unet/flux2_dev_fp8mixed.safetensors
ls -lh /workspace/ComfyUI/models/clip/mistral_3_small_flux2_bf16.safetensors
ls -lh /workspace/ComfyUI/models/vae/flux2-vae.safetensors
ls -lh /workspace/ComfyUI/models/loras/Flux2TurboComfyv2.safetensors
```

Expected output:
```
-rw-r--r-- 1 root root  34G Jan 13 15:00 flux2_dev_fp8mixed.safetensors
-rw-r--r-- 1 root root  34G Jan 13 15:15 mistral_3_small_flux2_bf16.safetensors
-rw-r--r-- 1 root root 321M Jan 13 15:00 flux2-vae.safetensors
-rw-r--r-- 1 root root 2.6G Jan 13 15:30 Flux2TurboComfyv2.safetensors
```

---

## 🔧 Troubleshooting

### Models Not Found
1. Check exact filenames (case-sensitive)
2. Verify file sizes match expected sizes
3. Ensure files are in correct directories
4. Restart ComfyUI after downloads complete

### Download Failures
1. Check internet connection
2. Verify HuggingFace is accessible
3. Check disk space (need 80GB+ free)
4. Review start.sh logs for errors

### Workflow Errors
1. Ensure ALL 4 core models are present
2. Check Turbo LoRA is loaded (critical for 4-8 step workflows)
3. Verify model filenames match workflow expectations
4. Try restarting ComfyUI

---

## 📝 Notes

- **BF16 Text Encoder:** Using BF16 for best quality (34GB) - system has sufficient VRAM
- **FP8 Diffusion:** FP8 quantization for speed while maintaining quality
- **No FLUX.1:** Only FLUX.2 models to avoid confusion and save storage
- **No GGUF:** Full precision models used - no quantization needed with sufficient VRAM
- **Public Repos:** All models from public HuggingFace repos (no authentication)

---

*Last updated: January 13, 2026*
*FLUX.2 Only - Optimized for 48GB+ VRAM systems*
