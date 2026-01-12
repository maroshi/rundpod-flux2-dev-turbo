# Required Models and LoRAs for FLUX.2 Workflows

This document lists all models and LoRAs required by the FLUX.2 workflows in this directory.

**Optimized for 48GB VRAM** - Using BF16/FP8 models (no GGUF quantization needed)

## Summary

All FLUX.2 workflows require these **core models** (auto-downloaded by start.sh):
- **Diffusion Model:** flux2_dev_fp8mixed.safetensors (~17GB FP8)
- **VAE:** flux2-vae.safetensors (~200MB)
- **Text Encoder:** mistral_3_small_flux2_bf16.safetensors (~5.6GB BF16)
- **Turbo LoRA:** Flux2TurboComfyv2.safetensors (~35MB)

---

## Workflow-Specific Requirements

### 1. flux2_turbo_2-8steps_sharcodin.json
**Type:** FLUX.2 Dev Turbo (2-8 steps)

**Required Models:**
- **Diffusion Model:** `flux2_dev_fp8mixed.safetensors` → `models/diffusion_models/`
- **Text Encoder:** `mistral_3_small_flux2_bf16.safetensors` → `models/text_encoders/`
- **VAE:** `flux2-vae.safetensors` → `models/vae/`
- **LoRA:** `Flux2TurboComfyv2.safetensors` → `models/loras/`

**Download URLs:**
- Text Encoder: https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/text_encoders/mistral_3_small_flux2_bf16.safetensors
- Diffusion Model: https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/diffusion_models/flux2_dev_fp8mixed.safetensors
- VAE: https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors
- LoRA: https://huggingface.co/ByteZSzn/Flux.2-Turbo-ComfyUI/tree/main

---

### 2. flux2_turbo_kombitz_6ref.json
**Type:** FLUX.2 Turbo with 6 Reference Images

**Required Models:**
- **Diffusion Model:** `flux2_dev_fp8mixed.safetensors` → `models/unet/`
- **Text Encoder:** `mistral_3_small_flux2_bf16.safetensors` → `models/text_encoders/`
- **VAE:** `flux2-vae.safetensors` → `models/vae/`
- **LoRA:** `Flux2TurboComfyv2.safetensors` → `models/loras/`

**Download URLs:**
- GGUF Model: https://huggingface.co/orabazes/FLUX.2-dev-GGUF
- Text Encoder: https://huggingface.co/unsloth/Mistral-Small-3.2-24B-Instruct-2506-GGUF
- LoRA: https://huggingface.co/ByteZSzn/Flux.2-Turbo-ComfyUI

---

### 3. flux2_turbo_default.json
**Type:** Default FLUX.2 Turbo Workflow

**Required Models:**
- **Checkpoint:** `flux2_dev_fp8mixed.safetensors` → `models/checkpoints/`
- **VAE:** `flux2-vae.safetensors` → `models/vae/`
- **LoRA:** `Flux2TurboComfyv2.safetensors` → `models/loras/`

**Notes:**
- Uses CheckpointLoaderSimple (all-in-one checkpoint format)
- 25 steps with cfg 3.5, euler_ancestral sampler

---

---

### Note: FLUX.1 Workflows Not Supported

The following workflows require FLUX.1 models and are **NOT auto-downloaded**:
- ❌ `flux_lora_xlabs.json` (requires flux1-dev-fp8.safetensors)
- ❌ `flux_lora_rundiffusion.json` (requires flux-1-dev-fp8.safetensors)

**Reason:** This setup is optimized for FLUX.2 only. FLUX.1 models would add ~17GB storage and are not needed for FLUX.2 workflows.

---

### 6. flux2_example_official.png
**Type:** Official ComfyUI FLUX.2 Example (PNG with embedded workflow)

**Required Models:** (Same as other FLUX.2 workflows)
- Diffusion model, VAE, text encoder, and LoRA for FLUX.2 Dev

---

## Automatic Download via start.sh

**All models are auto-downloaded on first container startup!**

The `start.sh` script automatically downloads all required FLUX.2 models to the correct directories. See `MODEL_DOWNLOADS.md` for details.

## Manual Download (If Needed)

If you want to pre-download models before starting the container:

```bash
# VAE (~200 MB)
wget https://huggingface.co/black-forest-labs/FLUX.2-dev/resolve/main/ae.safetensors \
  -O /workspace/ComfyUI/models/vae/flux2-vae.safetensors

# Text Encoder BF16 (~5.6 GB)
wget https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/text_encoders/mistral_3_small_flux2_bf16.safetensors \
  -O /workspace/ComfyUI/models/text_encoders/mistral_3_small_flux2_bf16.safetensors

# Diffusion Model FP8 (~17 GB)
wget https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/diffusion_models/flux2_dev_fp8mixed.safetensors \
  -O /workspace/ComfyUI/models/unet/flux2_dev_fp8mixed.safetensors

# Turbo LoRA (~35 MB)
wget https://huggingface.co/ByteZSzn/Flux.2-Turbo-ComfyUI/resolve/main/Flux2TurboComfyv2.safetensors \
  -O /workspace/ComfyUI/models/loras/Flux2TurboComfyv2.safetensors
```

---

## Model Directory Structure

```
ComfyUI/models/
├── checkpoints/          # All-in-one checkpoint files
│   └── flux2_dev_fp8mixed.safetensors
├── diffusion_models/     # Separated diffusion models (unet)
│   ├── flux2_dev_fp8mixed.safetensors
│   └── flux1-dev-fp8.safetensors
├── text_encoders/        # Text encoders (CLIP/T5/Mistral)
│   └── mistral_3_small_flux2_bf16.safetensors
├── vae/                  # VAE models
│   ├── flux2-vae.safetensors
│   └── ae.safetensors
├── loras/                # LoRA files
│   ├── Flux2TurboComfyv2.safetensors
│   └── [user LoRAs here]
└── unet/                 # GGUF quantized models
    └── [GGUF models here]
```

---

## Storage Requirements

### FLUX.2 Complete Setup (48GB VRAM Optimized)
- **Total:** ~23 GB
  - VAE: 0.2 GB
  - Text Encoder (BF16): 5.6 GB
  - Diffusion Model (FP8): 17 GB
  - Turbo LoRA: 0.035 GB

**Note:** BF16 text encoder used instead of FP8 for better quality since 48GB VRAM allows it.

---

## Download Order (Auto-Download Priority)

All models are downloaded automatically by `start.sh` in this order:

1. ✅ **VAE** - flux2-vae.safetensors (smallest, downloads first)
2. ✅ **Text Encoder** - mistral_3_small_flux2_bf16.safetensors (BF16 for quality)
3. ✅ **Diffusion Model** - flux2_dev_fp8mixed.safetensors (largest, ~17GB)
4. ✅ **Turbo LoRA** - Flux2TurboComfyv2.safetensors (enables fast generation)

---

## Notes

- **BF16 Text Encoder:** Using BF16 instead of FP8 for text encoder gives better quality with 48GB VRAM
- **FP8 Diffusion:** FP8 diffusion model saves VRAM while maintaining quality
- **Turbo LoRA:** Enables 2-8 step generation vs standard 20-50 steps
- **No GGUF Needed:** 48GB VRAM allows full precision models, no quantization needed
- **No FLUX.1:** Only FLUX.2 models are downloaded to save storage

## Key Improvements in start.sh

✅ **Fixed:** Models now download directly to correct directories (no `split_files/` subdirectories)
✅ **Fixed:** Uses proper file copy from HuggingFace cache to avoid structure issues
✅ **Optimized:** BF16 text encoder for 48GB VRAM systems
✅ **Compatible:** Diffusion model placed in both `unet/` and `diffusion_models/` for workflow compatibility

---

*Last updated: January 13, 2026*
*Optimized for 48GB VRAM - No FLUX.1, No GGUF, No split_files issues*
