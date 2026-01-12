# Flux.2 Dev Turbo LoRA Setup Guide

## Overview

This guide covers setting up and using **Flux.2 Dev Turbo LoRA** (Low-Rank Adaptation) models in ComfyUI. LoRA models allow you to quickly fine-tune image generation with minimal VRAM overhead while maintaining fast inference speeds.

**Key Benefits:**
- 🚀 Fast inference (~2-3x faster than base Flux.2 dev)
- 💾 Small model files (50-500MB vs 20GB+ for full models)
- 🎨 Style-specific or subject-specific fine-tuning
- ⚡ GPU-friendly - works on 16GB+ VRAM GPUs
- 🔄 Easy to stack multiple LoRAs in workflows

## Model Architecture

### Flux.2 Dev Turbo Requirements

**Base Models Needed:**
```
Diffusion Model:
├── flux2-dev.safetensors (21.6 GB)
└── OR flux2_dev_fp8mixed.safetensors (6.3 GB) [ComfyUI optimized]

Text Encoder:
├── mistral_3_small_flux2_bf16.safetensors
├── mistral_3_small_flux2_fp8.safetensors
└── OR t5xxl text encoder

VAE (Variational Autoencoder):
├── flux2-vae.safetensors
└── OR ae.safetensors [official]

LoRA Files:
├── flux.2-turbo-lora.safetensors (2.76 GB)
└── [Additional style/subject LoRAs...]
```

## Installation Steps

### Step 1: Download Flux.2 Dev Base Models

#### Option A: Official Models (Higher Quality, Larger)

```bash
# Diffusion Model (21.6 GB)
hf download black-forest-labs/FLUX.2-dev flux2-dev.safetensors \
--local-dir /workspace/ComfyUI/models/checkpoints/

# Text Encoder
hf download black-forest-labs/FLUX.2-dev text_encoder \
--local-dir /workspace/ComfyUI/models/text_encoders/

# VAE
hf download black-forest-labs/FLUX.2-dev ae.safetensors \
--local-dir /workspace/ComfyUI/models/vae/
```

#### Option B: ComfyUI Optimized Models (Smaller, Quantized)

```bash
# Diffusion Model - FP8 Mixed Precision (6.3 GB)
hf download Comfy-Org/flux2-dev split_files/diffusion_models/flux2_dev_fp8mixed.safetensors \
--local-dir /workspace/ComfyUI/models/checkpoints/

# Text Encoder - BF16 (1.3 GB)
hf download Comfy-Org/flux2-dev split_files/text_encoders/mistral_3_small_flux2_bf16.safetensors \
--local-dir /workspace/ComfyUI/models/text_encoders/

# VAE - Standard (230 MB)
hf download Comfy-Org/flux2-dev split_files/vae/flux2-vae.safetensors \
--local-dir /workspace/ComfyUI/models/vae/
```

**Recommended for VRAM-constrained systems:** Use Option B (ComfyUI optimized)

### Step 2: Download LoRA Models

#### Official Flux.2 Turbo LoRA

```bash
# Main Flux.2 Turbo LoRA (2.76 GB)
hf download fal/FLUX.2-dev-Turbo flux.2-turbo-lora.safetensors \
--local-dir /workspace/ComfyUI/models/loras/
```

#### ComfyUI-Optimized Turbo LoRA

```bash
# ComfyUI-specific Turbo variant (smaller, optimized)
hf download ByteZSzn/Flux.2-Turbo-ComfyUI Flux2TurboComfyv2.safetensors \
--local-dir /workspace/ComfyUI/models/loras/
```

#### Additional Style LoRAs

Browse HuggingFace for additional Flux.2 LoRAs:
- [XLabs-AI/flux-lora-collection](https://huggingface.co/XLabs-AI/flux-lora-collection)
- [Shakker-Labs/FLUX.1-dev-LoRA-collections](https://huggingface.co/Shakker-Labs/FLUX.1-dev-LoRA-collections)

```bash
# Example: Download multiple LoRAs
hf download <HF_MODEL_ID> <LORA_FILE.safetensors> \
--local-dir /workspace/ComfyUI/models/loras/
```

### Step 3: Configure LoRA Manager (Optional but Recommended)

Edit `/workspace/ComfyUI/custom_nodes/ComfyUI-Lora-Manager/settings.json.template`:

```json
{
  "use_portable_settings": false,
  "civitai_api_key": "your_civitai_api_key_here",
  "folder_paths": {
    "loras": [
      "/workspace/ComfyUI/models/loras"
    ],
    "checkpoints": [
      "/workspace/ComfyUI/models/checkpoints"
    ],
    "embeddings": []
  },
  "auto_organize_exclusions": []
}
```

## Using Flux.2 Turbo LoRA in ComfyUI

### Basic Workflow Structure

```
1. Load Checkpoint (Flux.2 Dev model)
   ↓
2. Load LoRA (Flux.2-Turbo-LoRA)
   ↓
3. Load Text Encoders (Mistral-3 Small)
   ↓
4. CLIP Text Encode (Positive Prompt)
   ↓
5. KSampler with Turbo-optimized settings
   ↓
6. VAE Decode (flux2-vae)
   ↓
7. Save Image
```

### Key Node Configuration

#### Load Checkpoint Node
```
Model: flux2-dev.safetensors (or flux2_dev_fp8mixed.safetensors)
Strength: 1.0
```

#### Load LoRA (Flux-Compatible) Node
```
Model: [Load from previous]
LoRA: Flux2TurboComfyv2.safetensors (or flux.2-turbo-lora.safetensors)
Strength: 0.8-1.0 (adjust for style intensity)
```

#### KSampler Configuration (Turbo Optimized)
```
Seed: [Your seed]
Steps: 20-28 (Turbo is optimized for fewer steps)
CFG: 3.5-4.5 (Lower CFG works better with Turbo)
Sampler: euler_ancestral or dpmpp_2m_sde
Scheduler: karras or simple
Denoise: 1.0 (Full denoise for best results)

⚠️ Note: Using more than 20-28 steps doesn't improve quality much with Turbo
```

#### Recommended Generation Settings
```
Resolution: 512x512, 768x512, 512x768, or 1024x1024
Batch Size: 1-4 (depending on VRAM)
```

## LoRA Strength & Blending

### Single LoRA Usage

```
strength_model: 1.0 (model weight)
strength_clip: 0.9-1.0 (text encoder weight)
```

- **0.5-0.7**: Subtle style influence
- **0.8-0.9**: Moderate style application
- **1.0**: Full LoRA effect

### Multiple LoRA Stacking

⚠️ **Important:** Flux.2 with multiple LoRAs **significantly increases inference time** (unlike Flux.1)

```
LoRA 1 (Turbo base):      strength = 1.0
LoRA 2 (Style):           strength = 0.5-0.7
LoRA 3 (Character):       strength = 0.5-0.6

Total node count per LoRA = ~4-5 steps overhead
```

**Recommendation:** Use 1-2 LoRAs maximum with Flux.2 Turbo for acceptable speed.

## Python Package Dependencies

The Docker image includes all required packages:

```python
# Core LoRA Support
diffusers>=0.29.0           # HuggingFace diffusion models
safetensors>=0.4.0          # Safe model file handling
huggingface-hub>=0.20.0     # Model downloading

# Advanced LoRA Features
peft>=0.8.0                 # Parameter-efficient fine-tuning
torch>=2.0.0                # PyTorch
torchvision>=0.18.0         # Vision utilities

# Optimization
onnxruntime-gpu>=1.22.0     # GPU-accelerated inference
```

### Verify Installation

```bash
python -c "
from diffusers import FluxPipeline
import torch
print('✓ Diffusers loaded')
print(f'✓ CUDA available: {torch.cuda.is_available()}')
print(f'✓ PyTorch version: {torch.__version__}')
"
```

## Troubleshooting

### Issue: LoRA not loading in ComfyUI
**Solution:**
1. Verify file is in `/workspace/ComfyUI/models/loras/`
2. Check filename matches exactly (case-sensitive)
3. Use LoRA Manager UI to refresh node menu: **Manager > Refresh**

### Issue: Out of Memory (OOM) errors
**Solution:**
1. Use FP8 models instead of full precision
2. Reduce batch size to 1
3. Lower resolution (512x512 instead of 1024x1024)
4. Use GGUF quantized models (ComfyUI-GGUF node)

### Issue: Slow inference with multiple LoRAs
**Solution:**
- Flux.2 Turbo doesn't optimize for multiple LoRA stacking
- Use single LoRA or blend effects in post-processing
- Consider using Flux.1 with multiple LoRAs if speed critical

### Issue: Poor quality results
**Solution:**
1. Verify text encoder is loaded (Mistral-3 Small)
2. Adjust CFG scale: Turbo works best at 3.5-4.5
3. Increase steps to 24-28 for complex prompts
4. Check VAE is loaded correctly

## Advanced: GGUF Quantized Models

For memory-constrained systems, use GGUF quantized models with ComfyUI-GGUF:

```bash
# Download GGUF Flux.2 variant
hf download city96/ComfyUI-GGUF-models flux2_dev_Q6_K.gguf \
--local-dir /workspace/ComfyUI/models/unet/
```

**Benefits:**
- Smaller model files (6-8 GB vs 21.6 GB)
- Lower VRAM requirements
- Minimal quality loss (Q6_K recommended)

## Performance Benchmarks

### Hardware Configurations

**RTX 4090 (24GB VRAM):**
- Model: flux2-dev.safetensors
- LoRA: Flux2TurboComfyv2 (strength=1.0)
- Resolution: 1024x1024
- Steps: 25
- **Time: ~3-4 seconds per image**

**RTX 4080 (16GB VRAM):**
- Model: flux2_dev_fp8mixed.safetensors (quantized)
- LoRA: Flux2TurboComfyv2
- Resolution: 768x768
- Steps: 20
- **Time: ~4-6 seconds per image**

**RTX 3090 (24GB VRAM):**
- Model: flux2_dev_fp8mixed.safetensors
- LoRA: Flux2TurboComfyv2
- Resolution: 512x768
- Steps: 20
- **Time: ~5-7 seconds per image**

## Model Management

### Directory Structure

```
/workspace/ComfyUI/models/
├── checkpoints/                 # Diffusion models
│   ├── flux2-dev.safetensors
│   └── flux2_dev_fp8mixed.safetensors
├── text_encoders/              # CLIP/T5 encoders
│   └── mistral_3_small_flux2_bf16.safetensors
├── vae/                         # VAE models
│   └── flux2-vae.safetensors
├── loras/                       # LoRA adapters
│   ├── flux.2-turbo-lora.safetensors
│   ├── Flux2TurboComfyv2.safetensors
│   └── [other_loras]/
└── unet/                        # GGUF quantized models
    └── flux2_dev_Q6_K.gguf
```

### Download Progress Tracking

For large models, use `huggingface-hub` progress:

```bash
export HF_HUB_ENABLE_HF_TRANSFER=1  # Faster downloads
hf download black-forest-labs/FLUX.2-dev flux2-dev.safetensors \
--local-dir /workspace/ComfyUI/models/checkpoints/ \
--resume-download
```

## References

- **Official Flux.2 Dev:** [black-forest-labs/FLUX.2-dev](https://huggingface.co/black-forest-labs/FLUX.2-dev)
- **Flux.2 Turbo LoRA:** [fal/FLUX.2-dev-Turbo](https://huggingface.co/fal/FLUX.2-dev-Turbo)
- **ComfyUI Docs:** [docs.comfy.org](https://docs.comfy.org)
- **LoRA Overview:** [ComfyUI Wiki - LoRA](https://comfyui-wiki.com/en/tutorial/basic/lora)

## Next Steps

1. Download base Flux.2 dev model
2. Download Flux.2 Turbo LoRA
3. Create a basic ComfyUI workflow
4. Experiment with CFG and step counts
5. Stack additional style LoRAs (if desired)
