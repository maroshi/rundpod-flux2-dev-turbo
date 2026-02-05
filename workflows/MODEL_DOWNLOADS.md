# FLUX.2 Model Downloads Configuration

## Overview

The `start.sh` script automatically downloads all required FLUX.2 Dev Turbo models on first container startup. All models are stored in `/workspace` (90TB+ storage) to avoid filling the root filesystem (15GB only).

**No manual downloads required!**

---

## 📦 What Gets Downloaded

### 1. VAE (~321 MB)
- **File:** `flux2-vae.safetensors`
- **Location:** `/workspace/ComfyUI/models/vae/`
- **Source:** Comfy-Org/flux2-dev (split_files/vae/)
- **Download order:** First (smallest file)

### 2. Text Encoder BF16 (~34 GB)
- **File:** `mistral_3_small_flux2_bf16.safetensors`
- **Location:** `/workspace/ComfyUI/models/clip/`
- **Source:** Comfy-Org/flux2-dev (split_files/text_encoders/)
- **Note:** Using BF16 for best quality (48GB+ VRAM systems)
- **Download order:** Second

### 3. Diffusion Model FP8 (~34 GB)
- **File:** `flux2_dev_fp8mixed.safetensors`
- **Location:** `/workspace/ComfyUI/models/unet/`
- **Source:** Comfy-Org/flux2-dev (split_files/diffusion_models/)
- **Note:** FP8 mixed precision for optimal speed/quality
- **Download order:** Third (largest)

### 4. Turbo LoRA (~2.6 GB)
- **File:** `Flux2TurboComfyv2.safetensors`
- **Location:** `/workspace/ComfyUI/models/loras/`
- **Source:** ByteZSzn/Flux.2-Turbo-ComfyUI
- **Purpose:** Enables 2-8 step fast generation
- **Download order:** Fourth (last)

---

## 💾 Total Storage Required

**~70 GB** total for all FLUX.2 models:
- VAE: 321 MB
- Text Encoder (BF16): 34 GB
- Diffusion Model (FP8): 34 GB
- Turbo LoRA: 2.6 GB

**Storage Location:** `/workspace` (90TB+ available on RunPod)

---

## 📂 Directory Structure

After auto-download completes:

```
/workspace/ComfyUI/models/
├── vae/
│   └── flux2-vae.safetensors                    [321 MB]
├── clip/
│   └── mistral_3_small_flux2_bf16.safetensors   [34 GB]
├── unet/
│   └── flux2_dev_fp8mixed.safetensors           [34 GB]
└── loras/
    └── Flux2TurboComfyv2.safetensors            [2.6 GB]
```

**Note:** Models are placed in flat directories (no `split_files/` subdirectories).

---

## 🔄 Download Behavior

### When Downloads Happen
- **Automatic:** On first container startup when models are missing
- **Skip:** If models already exist in target directories (checked with `find -maxdepth 1`)
- **Cached:** Uses HuggingFace cache at `/workspace/.cache/huggingface`

### Check Logic
For each model type, start.sh checks:
```bash
if ! find /workspace/ComfyUI/models/{directory} -maxdepth 1 -type f \
     \( -name "*.safetensors" -o -name "*.pt" \) 2>/dev/null | grep -q .; then
    # Download model
fi
```

The `-maxdepth 1` ensures only root directory is checked, preventing false positives from subdirectories.

### Download Method
1. Downloads file via `huggingface_hub.hf_hub_download()`
2. Downloads to HuggingFace cache first
3. Copies from cache to ComfyUI model directory
4. Ensures flat structure (no nested `split_files/` directories)
5. Provides progress feedback in console

### Error Handling
- Each model downloads independently
- Failures logged with ⚠️ warnings
- Container continues even if some downloads fail
- Check logs to identify failed downloads

---

## ✅ Workflow Compatibility

All downloaded models work with these FLUX.2 workflows:

### ✅ Supported Workflows (FLUX.2)
- **flux2_turbo_default.json** - Simple 4-step workflow
- **flux2_turbo_2-8steps_sharcodin.json** - Advanced 2-8 step workflow
- **flux2_turbo_kombitz_6ref.json** - Reference image workflow
- **flux2_example_official.png** - Official ComfyUI example

### ❌ Removed Workflows (FLUX.1 - Incompatible)
The following workflows have been **removed** and are NOT supported:
- **flux_lora_xlabs.json** - Required FLUX.1 models (DualCLIPLoader)
- **flux_lora_rundiffusion.json** - Required FLUX.1 models (DualCLIPLoader)

**Why removed:**
- FLUX.1 uses dual text encoders (T5-XXL + CLIP-L)
- FLUX.2 uses single text encoder (Mistral-3-Small)
- Different architectures = incompatible node types and LoRAs

---

## 🚫 Excluded Models (Not Downloaded)

### ❌ FLUX.1 Models
Not needed for FLUX.2 workflows:
- `flux1-dev-fp8.safetensors` (~34 GB)
- `clip_l.safetensors` (~246 MB)
- `t5xxl_fp16.safetensors` (~4.7 GB)
- `t5xxl_fp8_e4m3fn.safetensors` (~5.6 GB)

**Savings:** ~40 GB storage saved

### ❌ GGUF Quantized Models
Not needed with 48GB+ VRAM:
- GGUF diffusion models (~8-12 GB)
- GGUF text encoder models (~8-12 GB)

**Reason:** Full precision models preferred for quality when VRAM allows

### ❌ FP8 Text Encoder
Using BF16 instead:
- `mistral_3_small_flux2_fp8.safetensors` (NOT downloaded)
- **Reason:** BF16 provides better quality with available VRAM

---

## ⏱️ Download Time Estimates

Estimated download times (depends on network speed):

| Model | Size | Time (1 Gbps) | Time (100 Mbps) |
|-------|------|---------------|-----------------|
| VAE | 321 MB | ~3s | ~30s |
| Text Encoder | 34 GB | ~5 min | ~50 min |
| Diffusion Model | 34 GB | ~5 min | ~50 min |
| Turbo LoRA | 2.6 GB | ~25s | ~4 min |
| **Total** | **~70 GB** | **~10-12 min** | **~100 min** |

**First startup:** Allow 15-60 minutes for all models to download.

---

## 📥 Manual Download (Alternative)

If you prefer to pre-download before container start:

```bash
# Create model directories
mkdir -p /workspace/ComfyUI/models/{vae,clip,unet,loras}

# 1. VAE (~321 MB)
wget https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors \
  -O /workspace/ComfyUI/models/vae/flux2-vae.safetensors

# 2. Text Encoder BF16 (~34 GB)
wget https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/text_encoders/mistral_3_small_flux2_bf16.safetensors \
  -O /workspace/ComfyUI/models/clip/mistral_3_small_flux2_bf16.safetensors

# 3. Diffusion Model FP8 (~34 GB)
wget https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/diffusion_models/flux2_dev_fp8mixed.safetensors \
  -O /workspace/ComfyUI/models/unet/flux2_dev_fp8mixed.safetensors

# 4. Turbo LoRA (~2.6 GB)
wget https://huggingface.co/ByteZSzn/Flux.2-Turbo-ComfyUI/resolve/main/Flux2TurboComfyv2.safetensors \
  -O /workspace/ComfyUI/models/loras/Flux2TurboComfyv2.safetensors
```

---

## ✅ Verification

After container starts, verify model downloads:

```bash
# Check all models exist
find /workspace/ComfyUI/models -name "*.safetensors" -type f -exec ls -lh {} \;

# Check specific models with sizes
ls -lh /workspace/ComfyUI/models/vae/flux2-vae.safetensors
ls -lh /workspace/ComfyUI/models/clip/mistral_3_small_flux2_bf16.safetensors
ls -lh /workspace/ComfyUI/models/unet/flux2_dev_fp8mixed.safetensors
ls -lh /workspace/ComfyUI/models/loras/Flux2TurboComfyv2.safetensors

# Check disk usage
du -sh /workspace/ComfyUI/models/*
```

Expected output:
```
321M    /workspace/ComfyUI/models/vae/flux2-vae.safetensors
34G     /workspace/ComfyUI/models/clip/mistral_3_small_flux2_bf16.safetensors
34G     /workspace/ComfyUI/models/unet/flux2_dev_fp8mixed.safetensors
2.6G    /workspace/ComfyUI/models/loras/Flux2TurboComfyv2.safetensors
```

---

## 🎯 Performance Expectations

With these auto-downloaded models:

### Generation Speed
- **4 steps (Turbo):** ~6 seconds per image
- **8 steps:** ~12 seconds per image
- **2 steps (experimental):** ~4 seconds per image

### Image Quality
- **Excellent:** BF16 text encoder provides best quality
- **Fast:** FP8 diffusion model maintains quality while being efficient
- **Consistent:** Turbo LoRA optimized specifically for 2-8 step generation

### VRAM Usage During Generation
- **Typical:** 20-25 GB VRAM
- **Peak:** 30-35 GB VRAM
- **Batch processing:** 40-45 GB VRAM (multiple images)

### Supported Hardware
- **Minimum:** RTX 3090 (24GB VRAM) with FP8 models
- **Recommended:** RTX 4090 / A6000 (48GB VRAM) with BF16 quality
- **Optimal:** H100 / A100 (80GB VRAM) for batch processing

---

## 🔧 Troubleshooting

### Models Not Downloading
**Symptoms:** Container starts but models missing

**Solutions:**
1. Check internet connection in container:
   ```bash
   curl -I https://huggingface.co
   ```
2. Verify HuggingFace is accessible
3. Check disk space:
   ```bash
   df -h /workspace
   ```
4. Review start.sh logs:
   ```bash
   docker logs <container_id> | grep -A 5 "Step 19"
   ```

### Files in Wrong Directory (split_files)
**Symptoms:** Models in `/workspace/ComfyUI/models/vae/split_files/vae/`

**This should NOT happen with current start.sh!**

**If it does occur:**
```bash
# Move files to correct locations
cd /workspace/ComfyUI/models/vae
if [ -d split_files/vae ]; then
  mv split_files/vae/*.safetensors ./
  rm -rf split_files
fi
```

### Workflow Can't Find Models
**Symptoms:** "Model not found" errors in ComfyUI

**Solutions:**
1. Check exact filenames (case-sensitive):
   ```bash
   ls -la /workspace/ComfyUI/models/*/
   ```
2. Verify files are in correct directories:
   - VAE → `models/vae/`
   - Text Encoder → `models/clip/`
   - Diffusion → `models/unet/`
   - LoRA → `models/loras/`
3. Restart ComfyUI:
   ```bash
   # Inside container
   pkill -f comfyui
   /start.sh
   ```

### Download Failures (401 Errors)
**Symptoms:** `401 Client Error` during download

**Solutions:**
- Old issue with gated repo (black-forest-labs/FLUX.2-dev)
- **Fixed:** Now using public Comfy-Org/flux2-dev repo
- No authentication required!

### Slow Downloads
**Symptoms:** Downloads taking hours

**Solutions:**
1. Check network speed:
   ```bash
   speedtest-cli
   ```
2. Consider manual download with resume support:
   ```bash
   wget -c <url> -O <destination>
   ```
3. Use RunPod region with better connectivity

---

## 📝 Technical Details

### HuggingFace Download Implementation

The start.sh uses Python with `huggingface_hub` library:

```python
from huggingface_hub import hf_hub_download
import os

# Set cache location to workspace
os.environ['HF_HUB_CACHE'] = '/workspace/.cache/huggingface'

# Download with automatic caching
file_path = hf_hub_download(
    repo_id='Comfy-Org/flux2-dev',
    filename='split_files/vae/flux2-vae.safetensors',
    local_dir='/workspace/ComfyUI/models/vae'
)
```

### Key Features
- **Caching:** Uses `/workspace/.cache/huggingface` for efficient re-downloads
- **Resume:** Supports resume on interrupted downloads
- **Progress:** Shows download progress in console
- **No auth:** All repos are public (no HuggingFace token needed)

### Fixed Issues
- ✅ Models download to correct flat directories (no split_files)
- ✅ Uses `-maxdepth 1` to check only root directory
- ✅ Removed deprecated `local_dir_use_symlinks` parameter
- ✅ All models from public repos (no 401 auth errors)
- ✅ Storage allocated to `/workspace` (not root)

---

## 📊 Storage Allocation

### Root Filesystem (/)
- **Capacity:** 15 GB
- **Used by:** System, ComfyUI app, Docker
- **Available:** ~5 GB free
- **Usage:** 1% typically

### Workspace (/workspace)
- **Capacity:** 90 TB+
- **Used by:** Models, generated images, cache
- **Available:** ~90 TB free
- **Usage:** <1% (70GB models = 0.07% of 90TB)

**Critical:** All models MUST download to `/workspace` to avoid disk full errors!

---

## 🔒 Security & Privacy

### Model Sources
- **Public repos:** Comfy-Org/flux2-dev, ByteZSzn/Flux.2-Turbo-ComfyUI
- **No authentication:** No HuggingFace token required
- **No telemetry:** No usage tracking or data collection

### Local Storage
- **No cloud uploads:** All models stored locally
- **Persistent:** Models persist across container restarts
- **Private:** Generated images stay on your RunPod pod

---

*Last updated: January 13, 2026*
*FLUX.2 Only - Automatic downloads from public HuggingFace repos*
