# ComfyUI FLUX.2 Dev Turbo Workflows

This directory contains curated ComfyUI workflows optimized for FLUX.2 Dev and FLUX.2 Dev Turbo models.

## ⚠️ FLUX.2 Only - No FLUX.1 Compatibility

**Important:** These workflows are designed exclusively for FLUX.2 models. FLUX.1 workflows have been removed due to incompatibility:
- FLUX.2 uses **Mistral-3-Small** text encoder (single model)
- FLUX.1 uses **T5-XXL + CLIP-L** text encoders (dual model)
- Different model architectures, VAE structures, and LoRA formats

## 📂 Workflow Files

### 1. flux2_turbo_default.json ⭐ **Recommended for Beginners**
**Description:** Simple, fast FLUX.2 Turbo workflow with comprehensive documentation
**Features:**
- Built-in documentation nodes explaining setup, models, and architecture
- Optimized for 4-step generation (~6 seconds per image)
- Fixed 1024×1024 resolution
- Easy to understand for learning ComfyUI

**Required Models:**
- Diffusion: flux2_dev_fp8mixed.safetensors (~34GB)
- Text Encoder: mistral_3_small_flux2_bf16.safetensors (~34GB)
- VAE: flux2-vae.safetensors (~321MB)
- Turbo LoRA: Flux2TurboComfyv2.safetensors (~2.6GB)

**Performance:** ~6s per image on RTX 3090 (4 steps)

---

### 2. flux2_turbo_2-8steps_sharcodin.json
**Source:** [SharCodin/YouTube-Video-Archive](https://github.com/SharCodin/YouTube-Video-Archive/blob/main-branch/2026/Flux.2%20Dev/Flux.2%20Dev%20Turbo%202-8%20Steps.json)
**Created by:** Sharvin Suntoobacus (CodeCraftersCorner YouTube channel)
**Description:** Advanced FLUX.2 Turbo workflow with flexible 2-8 step range

**Features:**
- SamplerCustomAdvanced with Flux2Scheduler
- Resolution-aware custom scheduler
- Default: 2 steps (1088×1920 ultrawide)
- Adjustable guidance (FluxGuidance: 4.0)
- GGUF model support (quantized models)
- Professional workflow organization

**Required Models:** Same as default + optional GGUF models

**Performance:** Variable (2-8 steps configurable)

---

### 3. flux2_turbo_kombitz_6ref.json
**Source:** [Kombitz Guide](https://www.kombitz.com/2026/01/01/how-to-use-flux-2-dev-turbo-lora-in-comfyui-with-gguf-models/)
**Description:** Advanced workflow with 6 reference image support for style transfer

**Features:**
- 6 simultaneous reference images via subgraphs
- Image-to-image conditioning with ReferenceLatent nodes
- Variable aspect ratios (default: 1088×1920)
- Professional production workflow
- Markdown documentation notes

**Required Models:** Same as default

**Use Cases:**
- Style transfer from reference images
- Concept exploration with visual guidance
- Production work requiring consistency

**Performance:** 8 steps default (~12-15s per image)

---

### 4. flux2_example_official.png
**Source:** [ComfyUI Official Examples](https://github.com/comfyanonymous/ComfyUI_examples/tree/master/flux2)
**Format:** PNG with embedded workflow (drag into ComfyUI to load)
**Description:** Official ComfyUI FLUX.2 Dev example workflow

**Required Models:** Same as all FLUX.2 workflows

---

## 🔧 Model Requirements

### Core Models (Auto-Downloaded)
All models are automatically downloaded to `/workspace` on first startup:

| Model | File | Size | Location |
|-------|------|------|----------|
| **Diffusion** | flux2_dev_fp8mixed.safetensors | ~34GB | `models/unet/` |
| **Text Encoder** | mistral_3_small_flux2_bf16.safetensors | ~34GB | `models/clip/` |
| **VAE** | flux2-vae.safetensors | ~321MB | `models/vae/` |
| **Turbo LoRA** | Flux2TurboComfyv2.safetensors | ~2.6GB | `models/loras/` |

**Total:** ~70GB storage required

### Download Sources
- **FLUX.2 Models:** [Comfy-Org/flux2-dev](https://huggingface.co/Comfy-Org/flux2-dev) (public, no auth)
- **Turbo LoRA:** [ByteZSzn/Flux.2-Turbo-ComfyUI](https://huggingface.co/ByteZSzn/Flux.2-Turbo-ComfyUI)
- **Official FLUX.2:** [black-forest-labs/FLUX.2-dev](https://huggingface.co/black-forest-labs/FLUX.2-dev) (gated, requires auth)

## 📖 Usage

### Getting Started
1. **Load JSON workflow:** Use ComfyUI's "Load" button → select `.json` file
2. **Load PNG workflow:** Drag `flux2_example_official.png` directly into ComfyUI
3. **First run:** Models auto-download on startup (may take 30-60 minutes)
4. **Edit prompt:** Modify the positive prompt text in CLIPTextEncode node
5. **Generate:** Click "Queue Prompt" to generate image

### Workflow Selection Guide

**Choose flux2_turbo_default.json if you:**
- Are new to ComfyUI or FLUX.2
- Want simple, fast generation (~6s)
- Need built-in documentation
- Prefer standard square images (1024×1024)

**Choose flux2_turbo_2-8steps_sharcodin.json if you:**
- Want flexible step control (2-8 steps)
- Need ultrawide/custom aspect ratios
- Want advanced sampling controls
- Are comfortable with complex workflows

**Choose flux2_turbo_kombitz_6ref.json if you:**
- Need reference image style transfer
- Want to guide generation with visual examples
- Require professional production features
- Work with consistent visual styles

## ⚡ Performance Tips

### Speed Optimization
- **4 steps:** Fastest (~6s) - Good quality with Turbo LoRA
- **8 steps:** Balanced (~12s) - Better quality, still fast
- **2 steps:** Experimental (~4s) - Lower quality but very fast
- **20-25 steps:** Don't use with Turbo LoRA (not optimized)

### Quality Optimization
- **BF16 text encoder:** Best quality (34GB) - used by default
- **FP8 text encoder:** Faster, less VRAM (~5.6GB) - lower quality
- **CFG 1.0:** Optimal for Turbo (default)
- **Euler sampler:** Best for Turbo workflows

### VRAM Requirements
- **Minimum:** 24GB VRAM (with FP8 models)
- **Recommended:** 48GB VRAM (for BF16 quality)
- **Optimal:** 80GB VRAM (for batch processing)

## 📊 Workflow Comparison

| Feature | Default | 2-8 Steps | 6ref |
|---------|---------|-----------|------|
| **Complexity** | Simple (10 nodes) | Advanced (26 nodes) | Advanced (26 nodes) |
| **Speed** | ~6s (4 steps) | ~4-12s (2-8 steps) | ~12s (8 steps) |
| **Resolution** | 1024×1024 fixed | 1088×1920 variable | 1088×1920 variable |
| **Documentation** | Extensive built-in | MarkdownNote | MarkdownNote + links |
| **Reference Images** | No | No | Yes (6 images) |
| **Best For** | Learning, speed | Flexibility, control | Style transfer |

## 🚫 Removed Workflows (FLUX.1 Incompatible)

The following workflows have been **removed** due to FLUX.1 incompatibility:

### ❌ flux_lora_xlabs.json
- Required: DualCLIPLoader (T5-XXL + CLIP-L)
- Required: flux1-dev-fp8.safetensors
- **Reason:** FLUX.1 text encoder architecture incompatible with FLUX.2

### ❌ flux_lora_rundiffusion.json
- Required: DualCLIPLoader (T5-XXL + CLIP-L)
- Required: flux-1-dev-fp8.safetensors
- **Reason:** FLUX.1 models and LoRAs don't work with FLUX.2

**Note:** FLUX.1 LoRAs are NOT compatible with FLUX.2. Only use FLUX.2-specific LoRAs.

## 📚 Additional Resources

### Official Documentation
- [ComfyUI FLUX.2 Documentation](https://docs.comfy.org/tutorials/flux/flux-2-dev)
- [FLUX.2 Blog Post](https://blog.comfy.org/p/flux2-state-of-the-art-visual-intelligence)
- [Black Forest Labs FLUX.2 Release](https://blackforestlabs.ai/flux-2/)

### Community Guides
- [Kombitz FLUX.2 Turbo Guide](https://www.kombitz.com/2026/01/01/how-to-use-flux-2-dev-turbo-lora-in-comfyui-with-gguf-models/)
- [SharCodin YouTube Channel](https://www.youtube.com/@CodeCraftersCorner)

### Model Downloads
- [Comfy-Org FLUX.2 Models](https://huggingface.co/Comfy-Org/flux2-dev) (Recommended)
- [ByteZSzn Turbo LoRA](https://huggingface.co/ByteZSzn/Flux.2-Turbo-ComfyUI)
- [FLUX.2 GGUF Models](https://huggingface.co/orabazes/FLUX.2-dev-GGUF) (Optional)

## 🔍 Troubleshooting

### Models Not Loading
1. Check file names match exactly (case-sensitive)
2. Verify files are in correct directories (see Model Requirements)
3. Ensure models finished downloading (check file sizes)
4. Restart ComfyUI after model downloads

### Generation Errors
1. Ensure Turbo LoRA is loaded (required for 4-8 step generation)
2. Don't use high step counts (20+) with Turbo LoRA
3. Check VRAM usage (24GB minimum required)
4. Try reducing batch size if out of memory

### Slow Generation
1. Use 4 steps for fastest results
2. Ensure FP8 quantized models are used
3. Check GPU utilization (should be near 100%)
4. Close other VRAM-intensive applications

---

*Last updated: January 13, 2026*
*FLUX.2 Only - FLUX.1 workflows removed due to incompatibility*
