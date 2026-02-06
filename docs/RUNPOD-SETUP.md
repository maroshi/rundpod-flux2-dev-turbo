# RunPod Setup Guide

This guide walks you through deploying the FLUX.2 image generation service on RunPod with model selection capabilities.

## Quick Start with Model Selection

Deploy your pod in 4 steps:

1. **Create Pod Template** - Configure container image and model selection
2. **Deploy Pod** - Choose GPU and launch
3. **Verify Startup** - Check logs for successful model downloads
4. **Access ComfyUI** - Start generating images

---

## Step 1: Create Pod Template

1. Go to RunPod → Templates → New Template
2. Fill in template details:

### Container Image

```
ghcr.io/maroshi/flux2-dev-turbo:latest
```

### Container Disk

**10 GB minimum** (for system files and ComfyUI)

### Volume Disk

Choose based on your model selection:

- **Common models**: 10 GB minimum
- **Klein models**: 40 GB minimum
- **Dev models**: 70 GB minimum
- **All models**: 90 GB minimum

See [Storage Planning Table](#storage-planning) below for detailed breakdown.

### Expose Ports

Configure two HTTP ports:

- **Port 8188** - ComfyUI Web UI
- **Port 9000** - Code-Server (VS Code in browser)

### Environment Variables

**Required:**

```bash
FLUX_MODEL=klein           # Choose: klein, dev, all, or common
HF_TOKEN=your_token_here   # Get from https://huggingface.co/settings/tokens
```

**Optional:**

```bash
# If using self-hosted Code-Server
CODE_SERVER_PASSWORD=your_secure_password
```

### Model Selection Options

| Value | Models Downloaded | Use Case |
|-------|------------------|----------|
| `klein` | FLUX.2 Klein (3 models) + common | Fast inference, lower VRAM, good quality |
| `dev` | FLUX.2 Dev (4 models) + common | Highest quality, more VRAM required |
| `all` | All FLUX.2 models (7 total) | Full flexibility, maximum storage |
| `common` | Shared models only (VAE, encoders) | Custom model downloads |

---

## Step 2: Deploy Pod

1. Go to RunPod → Pods → Deploy
2. Select GPU type (see [GPU Recommendations](#gpu-recommendations))
3. Choose the template you created
4. Click **Deploy**

### GPU Selection

- **RTX 4090** - Best for Klein models (24GB VRAM)
- **A6000** - Good for Dev models (48GB VRAM)
- **RTX 3090** - Budget option for Klein (24GB VRAM)
- **A100** - Overkill but fastest (40GB/80GB VRAM)

---

## Step 3: Verify Startup

### Expected Log Output

After pod starts, check logs for successful model downloads:

```
🚀 Starting FLUX.2 Image Generation Service
📦 Model Selection: klein
🔑 HuggingFace token: Configured

📥 Downloading models in parallel...
⏳ Model downloads: 1/4 completed
⏳ Model downloads: 2/4 completed
⏳ Model downloads: 3/4 completed
⏳ Model downloads: 4/4 completed

✅ All models downloaded successfully!
📊 Download Statistics:
   • Total size: 32.5 GB
   • Download time: 3m 45s
   • Average speed: 145 MB/s

🎨 Starting ComfyUI...
✓ ComfyUI started successfully
🌐 Web UI: http://0.0.0.0:8188
🖥️  Code-Server: http://0.0.0.0:9000
```

### Startup Time Estimates

| Model Selection | Download Size | Time (100 Mbps) | Time (1 Gbps) |
|----------------|---------------|-----------------|---------------|
| `common` | ~10 GB | 13 minutes | 1-2 minutes |
| `klein` | ~32 GB | 43 minutes | 4-5 minutes |
| `dev` | ~65 GB | 87 minutes | 8-10 minutes |
| `all` | ~76 GB | 102 minutes | 10-12 minutes |

---

## Step 4: Access ComfyUI

### Web UI (ComfyUI)

1. Go to RunPod → Pods → Your Pod
2. Click **Connect** → **HTTP Service [Port 8188]**
3. ComfyUI interface will open in new tab

### Code-Server (VS Code)

1. Click **Connect** → **HTTP Service [Port 9000]**
2. Enter password if configured (`CODE_SERVER_PASSWORD`)
3. VS Code interface will open in browser

### Direct URLs

If you know your pod ID:

```
ComfyUI:      https://{pod-id}-8188.proxy.runpod.net
Code-Server:  https://{pod-id}-9000.proxy.runpod.net
```

---

## Model Selection Recommendations

### When to Use `klein` (Recommended for Most Users)

**Best for:**
- Fast iteration and experimentation
- Cost-effective GPU usage (RTX 3090/4090)
- Production workloads with good quality requirements

**Pros:**
- 2-3x faster inference than Dev
- Lower VRAM usage (~12-16 GB)
- Good image quality for most use cases
- 50% less storage than Dev

**Cons:**
- Slightly lower quality than Dev models
- Fewer fine-tuning options

### When to Use `dev`

**Best for:**
- Highest quality image generation
- Professional/commercial work
- Fine-grained control over outputs

**Pros:**
- Best image quality
- More advanced features
- Better prompt understanding

**Cons:**
- Slower inference (2-3x Klein)
- Requires more VRAM (~20-24 GB)
- 2x storage requirements

### When to Use `all`

**Best for:**
- Research and development
- A/B testing different models
- Maximum flexibility

**Pros:**
- Access to all model variants
- Can switch models without redeployment

**Cons:**
- Highest storage requirements (90 GB)
- Longer initial download time
- Wastes storage if you only use one model

### When to Use `common`

**Best for:**
- Custom model deployment
- Manual model management
- Minimal base installation

**Pros:**
- Smallest download (10 GB)
- Full control over model selection
- Can add custom checkpoints

**Cons:**
- Requires manual model downloads
- No FLUX models included by default

---

## Storage Planning

### Detailed Storage Breakdown

| Model Selection | VAE | Text Encoders | FLUX Models | Total |
|----------------|-----|---------------|-------------|-------|
| `common` | 335 MB | 9.8 GB | 0 GB | **~10 GB** |
| `klein` | 335 MB | 9.8 GB | 22 GB (3 files) | **~32 GB** |
| `dev` | 335 MB | 9.8 GB | 55 GB (4 files) | **~65 GB** |
| `all` | 335 MB | 9.8 GB | 66 GB (7 files) | **~76 GB** |

### Recommended Volume Sizes

| Model Selection | Minimum | Recommended | With Safety Margin |
|----------------|---------|-------------|-------------------|
| `common` | 10 GB | 15 GB | 20 GB |
| `klein` | 40 GB | 50 GB | 60 GB |
| `dev` | 70 GB | 80 GB | 100 GB |
| `all` | 90 GB | 100 GB | 120 GB |

**Note:** Safety margin accounts for temporary files, logs, and generated images.

---

## GPU Recommendations

### FLUX.2 Klein Models

| GPU | VRAM | Status | Batch Size | Notes |
|-----|------|--------|------------|-------|
| RTX 3090 | 24 GB | ✅ Excellent | 1-2 | Best price/performance |
| RTX 4090 | 24 GB | ✅ Excellent | 1-2 | Faster than 3090 |
| A6000 | 48 GB | ✅ Excellent | 4-8 | Overkill for Klein |
| RTX 3080 | 10 GB | ⚠️ Limited | 1 | Tight on VRAM |
| A100 | 40/80 GB | ✅ Excellent | 8+ | Overkill for Klein |

### FLUX.2 Dev Models

| GPU | VRAM | Status | Batch Size | Notes |
|-----|------|--------|------------|-------|
| RTX 3090 | 24 GB | ⚠️ Limited | 1 | May need optimizations |
| RTX 4090 | 24 GB | ✅ Good | 1 | Works well |
| A6000 | 48 GB | ✅ Excellent | 2-4 | Recommended |
| RTX 3080 | 10 GB | ❌ Insufficient | - | Not recommended |
| A100 | 40/80 GB | ✅ Excellent | 4-8 | Best for production |

### Cost Optimization Tips

1. **Start with Klein** - Test with Klein models first, upgrade to Dev if needed
2. **Use Spot Instances** - Save 50-70% on GPU costs (may be interrupted)
3. **Scale Down When Idle** - Stop pod when not generating images
4. **Persistent Storage** - Use network volumes to avoid re-downloading models

---

## Troubleshooting

### Issue 1: Models Not Downloading

**Symptoms:**
```
Error: Failed to download model
HTTP 401: Unauthorized
```

**Solution:**
1. Verify `HF_TOKEN` is set correctly in environment variables
2. Check token has read permissions: https://huggingface.co/settings/tokens
3. Ensure you've accepted FLUX.2 model licenses on HuggingFace
4. Restart the pod after fixing token

### Issue 2: Out of Storage During Download

**Symptoms:**
```
Error: No space left on device
Download failed: flux-2-dev.safetensors
```

**Solution:**
1. Check your volume disk size matches [Storage Planning](#storage-planning)
2. Stop pod and increase volume size
3. Redeploy pod with larger volume
4. Consider switching to smaller model selection (`dev` → `klein`)

### Issue 3: ComfyUI Not Accessible

**Symptoms:**
- Port 8188 shows "Connection Refused"
- Logs show startup completed but UI not loading

**Solution:**
1. Wait 30-60 seconds after logs show "ComfyUI started"
2. Check pod logs for errors: `docker logs <container-id>`
3. Verify port 8188 is exposed in template settings
4. Try accessing via direct URL: `https://{pod-id}-8188.proxy.runpod.net`
5. Restart pod if issue persists

### Issue 4: Model Loading Errors in ComfyUI

**Symptoms:**
```
Error: Model file not found
Unable to load checkpoint
```

**Solution:**
1. Check logs to verify all models downloaded successfully
2. Verify `FLUX_MODEL` environment variable is set correctly
3. Check model files exist in `/workspace/ComfyUI/models/`:
   ```bash
   ls -lh /workspace/ComfyUI/models/unet/
   ls -lh /workspace/ComfyUI/models/clip/
   ls -lh /workspace/ComfyUI/models/vae/
   ```
4. If models missing, check download logs for failures
5. Try restarting pod to retry failed downloads

---

## Best Practices

### 1. Use Network Volumes for Persistence

**Why:** Avoid re-downloading models on every pod restart

```bash
# In RunPod template settings:
Volume Mount Path: /workspace
Volume Size: Based on model selection (see Storage Planning)
```

**Benefits:**
- Models persist across pod restarts
- Faster startup times (skip downloads)
- Save bandwidth and time

### 2. Set Model Selection Early

**Why:** Changing models later requires re-downloading

**Recommendation:**
- Start with `klein` for testing
- Upgrade to `dev` only if quality requires it
- Use `all` only for research/comparison

### 3. Monitor Storage Usage

**Why:** Prevent out-of-space errors during operation

```bash
# Check storage from Code-Server terminal:
df -h /workspace
du -sh /workspace/ComfyUI/models/*
```

### 4. Use Environment Variables for Configuration

**Why:** Easier to manage and reproduce deployments

**Recommended variables:**
```bash
FLUX_MODEL=klein                          # Model selection
HF_TOKEN=hf_xxx                          # HuggingFace token
CODE_SERVER_PASSWORD=secure_password     # Code-Server access
```

### 5. Test Before Production

**Recommended workflow:**
1. Deploy pod with `klein` models
2. Test your workflows and prompts
3. Measure quality and performance
4. Upgrade to `dev` if needed
5. Lock down template for production use

---

## Support and Resources

### Documentation

- **Main README**: `/workspace/ComfyUI/README.md`
- **Model Loading Guide**: `/workspace/ComfyUI/docs/MODEL-LOADING.md`
- **Testing Guide**: `/workspace/ComfyUI/docs/TESTING.md`

### External Resources

- **FLUX.2 Models**: https://huggingface.co/black-forest-labs
- **ComfyUI Docs**: https://github.com/comfyanonymous/ComfyUI
- **RunPod Docs**: https://docs.runpod.io/

### Getting Help

1. Check logs first: `docker logs <container-id>`
2. Review this troubleshooting section
3. Check GitHub issues: https://github.com/maroshi/flux2-dev-turbo/issues
4. RunPod community: https://discord.gg/runpod

---

## Quick Reference

### Environment Variables

| Variable | Required | Values | Default |
|----------|----------|--------|---------|
| `FLUX_MODEL` | Yes | `klein`, `dev`, `all`, `common` | None |
| `HF_TOKEN` | Yes | Your HuggingFace token | None |
| `CODE_SERVER_PASSWORD` | No | Any string | None (no auth) |

### Port Mappings

| Service | Internal Port | Expose As | Purpose |
|---------|--------------|-----------|---------|
| ComfyUI | 8188 | HTTP | Web UI for image generation |
| Code-Server | 9000 | HTTP | VS Code in browser |

### Common Commands

```bash
# Check model downloads
ls -lh /workspace/ComfyUI/models/unet/
ls -lh /workspace/ComfyUI/models/clip/
ls -lh /workspace/ComfyUI/models/vae/

# Check storage usage
df -h /workspace
du -sh /workspace/ComfyUI/models/*

# View startup logs
cat /workspace/startup.log

# Restart ComfyUI (from Code-Server terminal)
pkill -f "python main.py"
cd /workspace/ComfyUI && python main.py --listen 0.0.0.0 --port 8188
```

---

**Last Updated:** 2026-02-06
**Version:** 1.0.0
