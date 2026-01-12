# Flux.2 Turbo Workflows & REST API Setup Guide

Complete guide for using Flux.2 Turbo default workflow with REST API automation.

## Overview

This setup provides:
- ✅ **Default Flux.2 Turbo Workflow** - Pre-configured ComfyUI workflow
- ✅ **REST API Server** - HTTP endpoints for automation
- ✅ **Automatic Image Output** - Generated images auto-saved to `/workspace/output/`
- ✅ **Queue Management** - Control, pause, resume generations
- ✅ **Status Polling** - Real-time generation progress monitoring
- ✅ **Batch Processing** - Generate multiple images programmatically

## Quick Start

### Option 1: Start Everything (ComfyUI + REST API)

```bash
# Make script executable
chmod +x /home/dudi/dev/image-generation-prompt/rundpod-flux2-dev-turbo/start-with-api.sh

# Start both services
./start-with-api.sh
```

**Output:**
```
✓ ComfyUI started (PID: 1234)
✓ REST API started (PID: 5678)

Available Endpoints:
  • ComfyUI Web UI:    http://localhost:8188
  • REST API Health:   http://localhost:5000/api/health
  • Generate Image:    POST http://localhost:5000/api/generate
```

### Option 2: Start Only REST API (ComfyUI Running Separately)

```bash
./start-with-api.sh --api-only
```

### Option 3: Start Only ComfyUI (No REST API)

```bash
./start-with-api.sh --no-api
```

## File Structure

```
rundpod-flux2-dev-turbo/
├── workflows/
│   └── flux2_turbo_default.json          # Default workflow
├── api/
│   ├── comfyui_rest_api.py               # REST API server
│   └── requirements.txt                  # API dependencies
├── start-with-api.sh                     # Combined startup script
├── start.sh                              # Original ComfyUI start
└── documentation/
    ├── REST_API_GUIDE.md                 # API documentation
    ├── FLUX2_TURBO_LORA_SETUP.md         # Main setup guide
    ├── FLUX2_TURBO_WORKFLOWS_API_SETUP.md # This file
    ├── GHCR_SETUP.md                     # GitHub Container Registry setup
    ├── provisioning/
    │   └── hf_flux.2_turbo_lora.md       # LoRA setup guide
    └── ...
```

## Default Workflow Structure

The default workflow (`workflows/flux2_turbo_default.json`) includes:

```
1. Load Checkpoint
   ↓ (Flux.2 dev model)
2. Load LoRA
   ↓ (Flux.2 Turbo LoRA - strength: 1.0)
3. Text Encoder
   ↓ (Mistral-3 Small)
4. KSampler
   ↓ (Steps: 25, CFG: 3.5, Seed: auto)
5. VAE Decode
   ↓ (flux2-vae.safetensors)
6. Save Image
   ↓ (/workspace/ComfyUI/output/)
```

### Default Settings

```json
{
  "model": "flux2_dev_fp8mixed.safetensors",
  "lora": "Flux2TurboComfyv2.safetensors",
  "lora_strength": 1.0,
  "steps": 25,
  "cfg": 3.5,
  "width": 1024,
  "height": 1024,
  "sampler": "euler_ancestral",
  "scheduler": "karras"
}
```

## REST API Quick Reference

### Generate Image

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

**Response:**
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "queued"
}
```

### Check Status

```bash
curl http://localhost:5000/api/status/550e8400-e29b-41d4-a716-446655440000
```

**Response:**
```json
{
  "status": "processing",
  "progress": 0.65,
  "current_step": 16,
  "total_steps": 25
}
```

### List Generated Images

```bash
curl http://localhost:5000/api/outputs
```

**Response:**
```json
{
  "images": [
    "Flux2_Turbo_00003_.png",
    "Flux2_Turbo_00002_.png",
    "Flux2_Turbo_00001_.png"
  ],
  "total": 3
}
```

### Download Image

```bash
curl http://localhost:5000/api/image/Flux2_Turbo_00001_.png -o my_image.png
```

## Complete Workflow Setup

### 1. Prepare Models

Download required models to `/workspace/ComfyUI/models/`:

```bash
# Flux.2 Dev Checkpoint
hf download Comfy-Org/flux2-dev split_files/diffusion_models/flux2_dev_fp8mixed.safetensors \
--local-dir /workspace/ComfyUI/models/checkpoints/

# Text Encoder
hf download Comfy-Org/flux2-dev split_files/text_encoders/mistral_3_small_flux2_bf16.safetensors \
--local-dir /workspace/ComfyUI/models/text_encoders/

# VAE
hf download Comfy-Org/flux2-dev split_files/vae/flux2-vae.safetensors \
--local-dir /workspace/ComfyUI/models/vae/

# LoRA
hf download ByteZSzn/Flux.2-Turbo-ComfyUI Flux2TurboComfyv2.safetensors \
--local-dir /workspace/ComfyUI/models/loras/
```

### 2. Start Services

```bash
./start-with-api.sh
```

### 3. Generate Images

#### Via Web UI (ComfyUI)

1. Navigate to `http://localhost:8188`
2. Load default workflow from `workflows/flux2_turbo_default.json`
3. Modify prompts in the text nodes
4. Click **Queue Prompt**
5. Images save to `/workspace/ComfyUI/output/`

#### Via REST API

```python
import requests
import time

def generate_image(prompt):
    # Submit
    response = requests.post(
        'http://localhost:5000/api/generate',
        json={'prompt': prompt, 'steps': 25}
    )
    job_id = response.json()['job_id']

    # Poll
    while True:
        status = requests.get(f'http://localhost:5000/api/status/{job_id}').json()
        if status['status'] == 'completed':
            return status['output_image']
        time.sleep(1)

# Generate
image = generate_image('a beautiful sunset landscape')
print(f'Generated: {image}')
```

## Customizing the Default Workflow

### Modify Workflow JSON

Edit `workflows/flux2_turbo_default.json`:

```json
{
  "5": {
    "inputs": {
      "steps": 30,           // Increase steps
      "cfg": 4.0,            // Increase guidance
      "seed": 12345          // Fixed seed
    }
  },
  "8": {
    "inputs": {
      "width": 768,          // Change resolution
      "height": 768
    }
  }
}
```

### Change Default LoRA

```json
{
  "2": {
    "inputs": {
      "lora_name": "your_lora_name.safetensors",
      "strength_model": 0.8
    }
  }
}
```

### Adjust Sampler

```json
{
  "5": {
    "inputs": {
      "sampler_name": "dpmpp_2m_sde",  // Alternative sampler
      "scheduler": "simple"
    }
  }
}
```

## Docker Compose Setup (Production)

### Create `docker-compose.yml`

```yaml
version: '3.8'

services:
  comfyui:
    image: ls250824/run-comfyui-image:latest
    container_name: flux2-comfyui
    ports:
      - "8188:8188"
      - "9000:9000"
    volumes:
      - workspace:/workspace
    environment:
      COMFYUI_VRAM_MODE: HIGH_VRAM
      PASSWORD: ${COMFYUI_PASSWORD:-changeme}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8188/api/config"]
      interval: 30s
      timeout: 10s
      retries: 3

  rest-api:
    build:
      context: ./api
      dockerfile: Dockerfile
    container_name: flux2-api
    ports:
      - "5000:5000"
    volumes:
      - workspace:/workspace
    environment:
      COMFYUI_HOST: comfyui
      COMFYUI_PORT: 8188
      DEBUG: "false"
    depends_on:
      comfyui:
        condition: service_healthy
    restart: unless-stopped

volumes:
  workspace:
    driver: local
```

### Start

```bash
docker-compose up -d
```

## Advanced Usage

### Batch Processing

Generate multiple images:

```bash
#!/bin/bash

PROMPTS=(
  "a serene mountain landscape"
  "a futuristic city skyline"
  "a cozy forest cabin"
)

for prompt in "${PROMPTS[@]}"; do
  echo "Generating: $prompt"
  curl -X POST http://localhost:5000/api/generate \
    -H "Content-Type: application/json" \
    -d "{\"prompt\": \"$prompt\", \"steps\": 25}" \
    | jq -r '.job_id'
done

# Monitor all jobs
curl http://localhost:5000/api/queue | jq
```

### Custom Workflows

Create new workflows:

1. Design in ComfyUI web UI
2. Export via **Menu > Save (Open)**
3. Save as `workflows/my_workflow.json`
4. Use via REST API

### Model Variants

Switch models for different quality/speed:

```json
// Full precision (best quality, slowest)
"ckpt_name": "flux2-dev.safetensors"

// FP8 Mixed (balanced)
"ckpt_name": "flux2_dev_fp8mixed.safetensors"

// GGUF Quantized (fastest)
"ckpt_name": "flux2_dev_Q6_K.gguf"
```

## Performance Tuning

### For Speed (RTX 4080)

```json
{
  "steps": 20,
  "cfg": 3.5,
  "width": 512,
  "height": 512,
  "lora_strength": 0.8
}
```

### For Quality (RTX 4090)

```json
{
  "steps": 28,
  "cfg": 4.0,
  "width": 1024,
  "height": 1024,
  "lora_strength": 1.0
}
```

### For Memory (RTX 3060)

```json
{
  "steps": 20,
  "cfg": 3.5,
  "width": 512,
  "height": 512,
  "batch_size": 1
}
```

## Troubleshooting

### Workflow Not Loading

```bash
# Check workflow exists
ls workflows/flux2_turbo_default.json

# Validate JSON
python -m json.tool workflows/flux2_turbo_default.json

# Check ComfyUI models
curl http://localhost:8188/api/config | jq '.models'
```

### REST API Won't Start

```bash
# Check Python dependencies
pip install -r api/requirements.txt

# Check ComfyUI running
curl http://localhost:8188/api/config

# Check ports
netstat -tulpn | grep 5000

# Start with debug
DEBUG=true python api/comfyui_rest_api.py
```

### Slow Generation

```bash
# Check GPU usage
nvidia-smi -l 1

# Check queue
curl http://localhost:5000/api/queue

# Clear stuck jobs
curl -X POST http://localhost:5000/api/queue/clear
```

## API Environment Variables

```bash
export COMFYUI_HOST=localhost
export COMFYUI_PORT=8188
export API_HOST=0.0.0.0
export API_PORT=5000
export WORKSPACE_PATH=/workspace
export DEBUG=false
```

## Next Steps

1. **Download Models** - Follow setup instructions above
2. **Start Services** - Run `./start-with-api.sh`
3. **Test Web UI** - Open `http://localhost:8188`
4. **Test REST API** - Call `http://localhost:5000/api/health`
5. **Generate Images** - Use web UI or REST API
6. **Automate** - Build your integration with REST API

## Documentation

- **REST API Guide**: `REST_API_GUIDE.md` (Complete API reference)
- **Flux.2 LoRA Setup**: `provisioning/hf_flux.2_turbo_lora.md` (Model details)
- **Docker Setup**: `FLUX2_TURBO_SETUP.md` (Container configuration)

## Support

For issues:
1. Check logs: `tail -f /tmp/comfyui_api.log`
2. Review REST API Guide: `REST_API_GUIDE.md`
3. Check GitHub issues: https://github.com/maroshi/rundpod-flux2-dev-turbo/issues

---

**Last Updated:** January 2026
**Status:** Production Ready
**Version:** 1.0.0-flux2-turbo-workflows-api
