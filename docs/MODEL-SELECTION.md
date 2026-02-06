# FLUX.2 Model Selection Guide

## Overview

This guide explains how to selectively download FLUX.2 models at container startup to optimize storage usage, startup time, and cost.

**Key Benefits:**
- **Storage Optimization**: Download only what you need (3GB to 76GB)
- **Faster Startup**: Reduce pod initialization time (30 seconds to 10 minutes)
- **Cost Savings**: Lower storage costs on cloud platforms
- **Workflow-Specific**: Match model selection to your specific use case

## Model Categories

### Common Models (Required for All Workflows)

These models are **always downloaded** regardless of `FLUX_MODEL` setting:

| Model | Size | Location | Purpose |
|-------|------|----------|---------|
| `FLUX.2 VAE` | 330 MB | `/models/vae/` | Image encoding/decoding |
| `Hyper-FLUX.2-dev-8steps-lora.safetensors` | 2.4 GB | `/models/loras/` | Turbo acceleration |

**Total Common Size:** ~3GB

### Klein-Specific Models

Downloaded when `FLUX_MODEL=klein` or `FLUX_MODEL=all`:

| Model | Size | Location | Purpose |
|-------|------|----------|---------|
| `qwen_3_4b.safetensors` | 9.3 GB | `/models/text_encoders/` | Text encoder for Klein |
| `flux-2-klein-base-4b.safetensors` | 7.4 GB | `/models/unet/` | Klein base diffusion model |
| `flux-2-klein-4b.safetensors` | 7.4 GB | `/models/unet/` | Klein full diffusion model |

**Total Klein Size:** ~24GB (plus 3GB common = 27GB total)

### Dev-Specific Models

Downloaded when `FLUX_MODEL=dev` or `FLUX_MODEL=all`:

| Model | Size | Location | Purpose |
|-------|------|----------|---------|
| `clip_l.safetensors` | 246 MB | `/models/text_encoders/` | CLIP text encoder |
| `t5xxl_fp16.safetensors` | 9.1 GB | `/models/text_encoders/` | T5 XXL text encoder |
| `flux2-dev-bf16.safetensors` | 17.2 GB | `/models/diffusion_models/` | FLUX.2 Dev base model |
| `flux2-dev-fp8.safetensors` | 17.2 GB | `/models/diffusion_models/` | FLUX.2 Dev FP8 variant |

**Total Dev Size:** ~51GB (plus 3GB common = 54GB total)

## Selection Strategy

### `FLUX_MODEL=common` (Default)

**Use When:**
- Testing the container setup
- Minimal storage requirements
- Only using pre-downloaded custom models
- Experimenting with Turbo LoRA workflows

**Downloads:**
- VAE (330 MB)
- Turbo LoRA (2.4 GB)

**Total:** ~3GB | **Startup:** ~30 seconds

**Workflow Compatibility:**
- ✅ Custom workflows with pre-existing models
- ✅ Turbo LoRA acceleration (if base model provided separately)
- ❌ FLUX.2 Klein workflows
- ❌ FLUX.2 Dev workflows

---

### `FLUX_MODEL=klein`

**Use When:**
- Working specifically with FLUX.2 Klein models
- Need faster inference (4B parameter models)
- Lower VRAM requirements (4-6GB)
- Klein-optimized workflows

**Downloads:**
- Common models (3GB)
- Klein text encoder (9.3 GB)
- Klein base model (7.4 GB)
- Klein full model (7.4 GB)

**Total:** ~27GB | **Startup:** ~3-4 minutes

**Workflow Compatibility:**
- ✅ FLUX.2 Klein workflows
- ✅ Klein + Turbo LoRA acceleration
- ✅ Lower VRAM inference
- ❌ FLUX.2 Dev workflows

---

### `FLUX_MODEL=dev`

**Use When:**
- Working with FLUX.2 Dev models
- Need highest quality outputs (12B parameter models)
- Have sufficient VRAM (16GB+)
- Standard ComfyUI FLUX.2 workflows

**Downloads:**
- Common models (3GB)
- CLIP text encoder (246 MB)
- T5 XXL text encoder (9.1 GB)
- Dev BF16 model (17.2 GB)
- Dev FP8 model (17.2 GB)

**Total:** ~54GB | **Startup:** ~6-8 minutes

**Workflow Compatibility:**
- ✅ FLUX.2 Dev workflows
- ✅ Dev + Turbo LoRA acceleration
- ✅ Highest quality generation
- ❌ FLUX.2 Klein workflows

---

### `FLUX_MODEL=all`

**Use When:**
- Need both Klein and Dev models
- Switching between different model types
- Production environments supporting multiple workflows
- Maximum flexibility required

**Downloads:**
- All common, Klein, and Dev models

**Total:** ~76GB | **Startup:** ~8-10 minutes

**Workflow Compatibility:**
- ✅ All FLUX.2 Klein workflows
- ✅ All FLUX.2 Dev workflows
- ✅ Complete flexibility

## Configuration Examples

### RunPod Environment Variables

Set in pod configuration:

```bash
FLUX_MODEL=klein
```

### Docker Compose

```yaml
version: '3.8'

services:
  comfyui:
    image: ghcr.io/maroshi/flux2-dev-turbo:latest
    environment:
      - FLUX_MODEL=dev
    volumes:
      - ./workspace:/workspace
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

### Docker Run

```bash
# Klein models only
docker run -e FLUX_MODEL=klein ghcr.io/maroshi/flux2-dev-turbo:latest

# Dev models only
docker run -e FLUX_MODEL=dev ghcr.io/maroshi/flux2-dev-turbo:latest

# All models
docker run -e FLUX_MODEL=all ghcr.io/maroshi/flux2-dev-turbo:latest
```

### Dockerfile (Build-time Default)

```dockerfile
# Set default model selection (can be overridden at runtime)
ENV FLUX_MODEL=klein
```

## Verification

After container startup, check the logs:

### Expected Output

**For `FLUX_MODEL=common`:**
```
[INFO] FLUX_MODEL set to: common
[INFO] Downloading common models only (VAE + Turbo LoRA)
✅ Downloaded: FLUX.2 VAE (330 MB)
✅ Downloaded: Hyper-FLUX.2-dev-8steps-lora.safetensors (2.4 GB)
[INFO] Model downloads complete: 2/2 files (~3GB)
```

**For `FLUX_MODEL=klein`:**
```
[INFO] FLUX_MODEL set to: klein
[INFO] Downloading common + Klein models
✅ Downloaded: FLUX.2 VAE (330 MB)
✅ Downloaded: Hyper-FLUX.2-dev-8steps-lora.safetensors (2.4 GB)
✅ Downloaded: qwen_3_4b.safetensors (9.3 GB)
✅ Downloaded: flux-2-klein-base-4b.safetensors (7.4 GB)
✅ Downloaded: flux-2-klein-4b.safetensors (7.4 GB)
[INFO] Model downloads complete: 5/5 files (~27GB)
```

**For `FLUX_MODEL=dev`:**
```
[INFO] FLUX_MODEL set to: dev
[INFO] Downloading common + Dev models
✅ Downloaded: FLUX.2 VAE (330 MB)
✅ Downloaded: Hyper-FLUX.2-dev-8steps-lora.safetensors (2.4 GB)
✅ Downloaded: clip_l.safetensors (246 MB)
✅ Downloaded: t5xxl_fp16.safetensors (9.1 GB)
✅ Downloaded: flux2-dev-bf16.safetensors (17.2 GB)
✅ Downloaded: flux2-dev-fp8.safetensors (17.2 GB)
[INFO] Model downloads complete: 6/6 files (~54GB)
```

**For `FLUX_MODEL=all`:**
```
[INFO] FLUX_MODEL set to: all
[INFO] Downloading all models (Klein + Dev)
✅ Downloaded: FLUX.2 VAE (330 MB)
✅ Downloaded: Hyper-FLUX.2-dev-8steps-lora.safetensors (2.4 GB)
✅ Downloaded: qwen_3_4b.safetensors (9.3 GB)
✅ Downloaded: flux-2-klein-base-4b.safetensors (7.4 GB)
✅ Downloaded: flux-2-klein-4b.safetensors (7.4 GB)
✅ Downloaded: clip_l.safetensors (246 MB)
✅ Downloaded: t5xxl_fp16.safetensors (9.1 GB)
✅ Downloaded: flux2-dev-bf16.safetensors (17.2 GB)
✅ Downloaded: flux2-dev-fp8.safetensors (17.2 GB)
[INFO] Model downloads complete: 9/9 files (~76GB)
```

## Troubleshooting

### Issue: "Invalid FLUX_MODEL value"

**Symptom:**
```
[ERROR] Invalid FLUX_MODEL value: 'devv'. Valid options: common, klein, dev, all
[INFO] Falling back to default: common
```

**Solution:**
- Check spelling of `FLUX_MODEL` environment variable
- Valid values are: `common`, `klein`, `dev`, `all` (case-sensitive)
- Fix typo in pod environment variables

### Issue: Missing Models in ComfyUI

**Symptom:**
- Workflow fails with "Model not found" error
- ComfyUI shows red nodes for missing models

**Solution:**
1. Check model selection matches workflow requirements:
   - Klein workflows need `FLUX_MODEL=klein` or `all`
   - Dev workflows need `FLUX_MODEL=dev` or `all`
2. Verify model downloads completed successfully in logs
3. Restart pod with correct `FLUX_MODEL` value

### Issue: Storage Space Exceeded

**Symptom:**
```
[ERROR] Download failed: No space left on device
```

**Solution:**
1. Choose smaller model selection:
   - Use `common` (3GB) instead of `all` (76GB)
   - Use `klein` (27GB) for Klein workflows only
   - Use `dev` (54GB) for Dev workflows only
2. Increase pod storage allocation on RunPod
3. Clean up unnecessary files: `rm -rf /workspace/ComfyUI/output/*`

### Issue: Slow Download Speed

**Symptom:**
- Model downloads taking longer than expected
- Startup time exceeds estimates

**Solution:**
- Downloads run in parallel (7 simultaneous connections)
- Speed depends on HuggingFace CDN and network connection
- Expected speeds: 40-60 MB/s on good connections
- No action needed; downloads will complete eventually

## Best Practices

### 1. Match Model Selection to Workflow

**Before starting a pod:**
- Identify which FLUX.2 model your workflow uses (Klein vs Dev)
- Set `FLUX_MODEL` accordingly to avoid downloading unnecessary models

### 2. Use `common` for Testing

**When experimenting:**
- Start with `FLUX_MODEL=common` to test container setup
- Upgrade to `klein` or `dev` once you've confirmed workflow requirements

### 3. Plan Storage Allocation

**Storage planning:**
- **Testing:** 5-10 GB (common + workspace)
- **Klein workflows:** 30-35 GB (klein + workspace + outputs)
- **Dev workflows:** 60-70 GB (dev + workspace + outputs)
- **Production:** 80-100 GB (all + workspace + outputs + custom models)

### 4. Monitor Startup Logs

**Always check logs:**
- Verify expected number of model downloads completed
- Check for download errors or missing files
- Confirm total size matches expectations

### 5. Reuse Persistent Storage

**On RunPod with Network Volumes:**
- Models persist across pod restarts
- Only first startup requires full download time
- Subsequent startups skip existing models

---

**Related Documentation:**
- [README.md](../README.md) - Quick start guide
- [Dockerfile](../Dockerfile) - Build configuration
- [start.sh](../start.sh) - Startup script implementation
