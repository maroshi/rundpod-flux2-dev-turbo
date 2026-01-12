# ComfyUI FLUX.2 Dev Turbo Workflows

This directory contains curated ComfyUI workflows optimized for FLUX.2 Dev and FLUX.2 Dev Turbo models.

## Workflow Files

### 1. flux2_example_official.png
**Source:** [ComfyUI Official Examples](https://github.com/comfyanonymous/ComfyUI_examples/tree/master/flux2)
**Description:** Official ComfyUI FLUX.2 Dev example workflow
**Format:** PNG with embedded workflow (drag into ComfyUI to load)
**Use Case:** Basic FLUX.2 Dev text-to-image generation

### 2. flux2_turbo_2-8steps_sharcodin.json
**Source:** [SharCodin/YouTube-Video-Archive](https://github.com/SharCodin/YouTube-Video-Archive/blob/main-branch/2026/Flux.2%20Dev/Flux.2%20Dev%20Turbo%202-8%20Steps.json)
**Description:** FLUX.2 Dev Turbo workflow optimized for 2-8 inference steps
**Created by:** Sharvin Suntoobacus (CodeCraftersCorner YouTube channel)
**Required Models:**
- Text encoder: mistral_3_small_flux2_bf16.safetensors
- LoRA: Flux2TurboComfyv2.safetensors
- Diffusion model: flux2_dev_fp8mixed.safetensors
- VAE: flux2-vae.safetensors

### 3. flux2_turbo_default.json
**Description:** Default FLUX.2 Turbo workflow (existing)
**Use Case:** Standard FLUX.2 Turbo setup

### 4. flux2_turbo_kombitz_6ref.json
**Source:** [Kombitz Guide](https://www.kombitz.com/2026/01/01/how-to-use-flux-2-dev-turbo-lora-in-comfyui-with-gguf-models/)
**Description:** FLUX.2 Turbo workflow with 6 reference images support
**Steps:** Optimized for 8 steps
**Required Models:**
- GGUF model from: huggingface.co/orabazes/FLUX.2-dev-GGUF
- Text encoder: huggingface.co/unsloth/Mistral-Small-3.2-24B-Instruct-2506-GGUF
- LoRA: huggingface.co/ByteZSzn/Flux.2-Turbo-ComfyUI

### 5. flux_lora_xlabs.json
**Source:** [XLabs-AI x-flux-comfyui](https://github.com/XLabs-AI/x-flux-comfyui/blob/main/workflows/lora_workflow.json)
**Description:** FLUX LoRA workflow from XLabs-AI
**Use Case:** Advanced LoRA integration for FLUX models

### 6. flux_lora_rundiffusion.json
**Source:** [RunDiffusion Wonderman-Flux-POC](https://huggingface.co/RunDiffusion/Wonderman-Flux-POC/blob/9b487a08b97781d9b46fad08c58b47b868ba0e76/flux-with-lora-RunDiffusion-ComfyUI-Workflow.json)
**Description:** RunDiffusion's FLUX with LoRA workflow
**Use Case:** Production-ready FLUX workflow with LoRA support

## Model Requirements

### Core Models (place in respective directories)
- **VAE:** flux2-vae.safetensors → `models/vae/`
- **Text Encoders:** mistral_3_small_flux2_*.safetensors → `models/text_encoders/`
- **Diffusion Model:** flux2_dev_fp8mixed.safetensors → `models/checkpoints/` or `models/unet/`
- **Turbo LoRA:** Flux2TurboComfyv2.safetensors → `models/loras/`

### Download Sources
- **Official FLUX.2:** [black-forest-labs/FLUX.2-dev](https://huggingface.co/black-forest-labs/FLUX.2-dev)
- **Comfy-optimized:** [Comfy-Org/flux2-dev](https://huggingface.co/Comfy-Org/flux2-dev)
- **GGUF models:** [orabazes/FLUX.2-dev-GGUF](https://huggingface.co/orabazes/FLUX.2-dev-GGUF)
- **Turbo LoRA:** [ByteZSzn/Flux.2-Turbo-ComfyUI](https://huggingface.co/ByteZSzn/Flux.2-Turbo-ComfyUI)

## Usage

1. **Load PNG workflow:** Drag `flux2_example_official.png` directly into ComfyUI
2. **Load JSON workflow:** Use ComfyUI's "Load" button and select any `.json` file
3. **Configure models:** Ensure all required models are downloaded and placed in correct directories
4. **Set steps:** For Turbo workflows, use 2-8 steps for optimal speed/quality balance

## Performance Tips

- **Turbo LoRA:** Reduces inference steps to 2-8 (vs. standard 20-50 steps)
- **GGUF models:** Use quantized models to reduce VRAM usage
- **FP8 mixed precision:** Use fp8 versions for 40-50% memory savings
- **Optimal settings:** 8 steps is recommended for best speed/quality balance

## Additional Resources

- [ComfyUI FLUX.2 Documentation](https://docs.comfy.org/tutorials/flux/flux-2-dev)
- [FLUX.2 Blog Post](https://blog.comfy.org/p/flux2-state-of-the-art-visual-intelligence)
- [Kombitz FLUX.2 Turbo Guide](https://www.kombitz.com/2026/01/01/how-to-use-flux-2-dev-turbo-lora-in-comfyui-with-gguf-models/)

---
*Last updated: January 13, 2026*
