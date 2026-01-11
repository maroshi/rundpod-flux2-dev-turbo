# ComfyUI REST API Guide - Flux.2 Turbo LoRA

Complete guide for using the REST API to automate Flux.2 Turbo LoRA image generation.

## Overview

The REST API wrapper provides HTTP endpoints to:
- 🎨 Generate images from text prompts
- 📊 Monitor generation progress
- 🎛️ Control the generation queue
- 📥 Download generated images
- 🔍 Track job history

## Quick Start

### 1. Start the REST API Server

```bash
# Inside the container
cd /api
python comfyui_rest_api.py

# Or with environment variables
COMFYUI_HOST=localhost \
COMFYUI_PORT=8188 \
API_HOST=0.0.0.0 \
API_PORT=5000 \
python comfyui_rest_api.py
```

**Default Ports:**
- ComfyUI Web UI: `http://localhost:8188`
- REST API: `http://localhost:5000`

### 2. Test the API

```bash
# Health check
curl http://localhost:5000/api/health

# Generate image
curl -X POST http://localhost:5000/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "a beautiful sunset landscape",
    "steps": 25,
    "cfg": 3.5
  }'
```

## API Endpoints

### 1. Generate Image

**Endpoint:** `POST /api/generate`

**Generate an image from a text prompt**

```bash
curl -X POST http://localhost:5000/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "a serene mountain landscape with golden hour lighting",
    "negative_prompt": "blurry, low quality",
    "steps": 25,
    "cfg": 3.5,
    "width": 1024,
    "height": 1024,
    "lora_strength": 1.0,
    "sampler": "euler_ancestral",
    "scheduler": "karras",
    "batch_size": 1,
    "seed": 12345
  }'
```

**Request Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `prompt` | string | **required** | Image description (e.g., "a cat") |
| `negative_prompt` | string | "" | What to avoid (e.g., "blurry") |
| `steps` | integer | 25 | Diffusion steps (20-28 optimal for Turbo) |
| `cfg` | float | 3.5 | Classifier-free guidance scale (3.5-4.5 for Turbo) |
| `width` | integer | 1024 | Image width (512, 768, 1024) |
| `height` | integer | 1024 | Image height (512, 768, 1024) |
| `lora_strength` | float | 1.0 | LoRA influence (0.0-1.0) |
| `seed` | integer | auto | Random seed (for reproducibility) |
| `sampler` | string | "euler_ancestral" | Sampling method |
| `scheduler` | string | "karras" | Noise scheduler |
| `batch_size` | integer | 1 | Images per batch |

**Response (202 Accepted):**

```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "prompt_id": "a1b2c3d4",
  "status": "queued",
  "prompt": "a serene mountain landscape with golden hour lighting",
  "message": "Image generation queued"
}
```

**Use `job_id` to check status!**

---

### 2. Check Generation Status

**Endpoint:** `GET /api/status/<job_id>`

**Check the progress of a generation**

```bash
curl http://localhost:5000/api/status/550e8400-e29b-41d4-a716-446655440000
```

**Response:**

```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "processing",
  "prompt": "a serene mountain landscape with golden hour lighting",
  "progress": 0.65,
  "current_step": 16,
  "total_steps": 25,
  "output_image": null,
  "error": null,
  "created_at": "2026-01-11T20:30:45.123456"
}
```

**Status Values:**
- `queued` - Waiting in queue
- `processing` - Currently generating
- `completed` - Done! Check `output_image`
- `failed` - Error occurred (check `error` field)
- `cancelled` - User cancelled

---

### 3. Get Queue Status

**Endpoint:** `GET /api/queue`

**View all jobs in queue and running**

```bash
curl http://localhost:5000/api/queue
```

**Response:**

```json
{
  "queue": {
    "queue_pending": [[1, "prompt_id_1"], [2, "prompt_id_2"]],
    "queue_running": []
  },
  "jobs": {
    "job_id_1": {
      "job_id": "job_id_1",
      "status": "queued",
      "prompt": "...",
      "progress": 0.0
    }
  },
  "total_jobs": 2
}
```

---

### 4. Cancel Job

**Endpoint:** `DELETE /api/queue/<job_id>`

**Cancel a specific generation**

```bash
curl -X DELETE http://localhost:5000/api/queue/550e8400-e29b-41d4-a716-446655440000
```

**Response:**

```json
{
  "status": "success",
  "message": "Job 550e8400-e29b-41d4-a716-446655440000 cancelled"
}
```

---

### 5. Clear Queue

**Endpoint:** `POST /api/queue/clear`

**Stop all pending jobs**

```bash
curl -X POST http://localhost:5000/api/queue/clear
```

**Response:**

```json
{
  "status": "success",
  "message": "Queue cleared"
}
```

---

### 6. Download Image

**Endpoint:** `GET /api/image/<filename>`

**Download a generated image**

```bash
curl http://localhost:5000/api/image/Flux2_Turbo_00001_.png \
  -o my_image.png
```

Or in browser: `http://localhost:5000/api/image/Flux2_Turbo_00001_.png`

---

### 7. List Generated Images

**Endpoint:** `GET /api/outputs`

**Get all generated images**

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
  "total": 3,
  "output_dir": "/workspace/ComfyUI/output"
}
```

---

### 8. Get Execution History

**Endpoint:** `GET /api/history`

**View all executed prompts**

```bash
curl http://localhost:5000/api/history
```

**Response:**

```json
{
  "history": {
    "prompt_id_1": {
      "prompt": [...],
      "outputs": {...},
      "status": "success"
    }
  },
  "total_items": 5
}
```

---

### 9. List Available Workflows

**Endpoint:** `GET /api/workflows`

**Get available workflow templates**

```bash
curl http://localhost:5000/api/workflows
```

**Response:**

```json
{
  "workflows": [
    "flux2_turbo_default",
    "flux2_turbo_upscale",
    "flux2_turbo_controlnet"
  ],
  "total": 3
}
```

---

### 10. System Information

**Endpoint:** `GET /api/system`

**Get GPU and system stats**

```bash
curl http://localhost:5000/api/system
```

**Response:**

```json
{
  "devices": [
    {
      "name": "NVIDIA RTX 4090",
      "vram": 24576,
      "vram_free": 18432
    }
  ],
  "models": {...}
}
```

---

### 11. Health Check

**Endpoint:** `GET /api/health`

**Check API and ComfyUI status**

```bash
curl http://localhost:5000/api/health
```

**Response:**

```json
{
  "status": "healthy",
  "comfyui": "connected",
  "output_dir": "/workspace/ComfyUI/output",
  "system": {...}
}
```

---

## Usage Examples

### Python Client Example

```python
import requests
import time
import json

API_URL = 'http://localhost:5000'

def generate_image(prompt, steps=25, cfg=3.5):
    """Generate image and wait for completion"""

    # 1. Submit request
    response = requests.post(
        f'{API_URL}/api/generate',
        json={
            'prompt': prompt,
            'steps': steps,
            'cfg': cfg,
            'width': 1024,
            'height': 1024
        }
    )
    response.raise_for_status()
    job = response.json()
    job_id = job['job_id']

    print(f'Generation started: {job_id}')

    # 2. Poll for status
    while True:
        status_response = requests.get(f'{API_URL}/api/status/{job_id}')
        status = status_response.json()

        if status['status'] == 'completed':
            print(f'✓ Completed: {status["output_image"]}')
            return status['output_image']
        elif status['status'] == 'failed':
            print(f'✗ Failed: {status["error"]}')
            return None
        else:
            progress = status.get('progress', 0) * 100
            print(f'  Progress: {progress:.1f}% ({status["current_step"]}/{status["total_steps"]})')
            time.sleep(2)

# Usage
image = generate_image('a beautiful sunset landscape')
```

### JavaScript/Node.js Example

```javascript
const axios = require('axios');

const API_URL = 'http://localhost:5000';

async function generateImage(prompt, options = {}) {
  try {
    // 1. Submit generation
    const response = await axios.post(`${API_URL}/api/generate`, {
      prompt: prompt,
      steps: options.steps || 25,
      cfg: options.cfg || 3.5,
      width: options.width || 1024,
      height: options.height || 1024
    });

    const jobId = response.data.job_id;
    console.log(`Generation started: ${jobId}`);

    // 2. Poll for completion
    while (true) {
      const statusResponse = await axios.get(`${API_URL}/api/status/${jobId}`);
      const status = statusResponse.data;

      if (status.status === 'completed') {
        console.log(`✓ Completed: ${status.output_image}`);
        return status.output_image;
      } else if (status.status === 'failed') {
        console.error(`✗ Failed: ${status.error}`);
        return null;
      } else {
        const progress = (status.progress * 100).toFixed(1);
        console.log(`Progress: ${progress}% (${status.current_step}/${status.total_steps})`);
        await new Promise(resolve => setTimeout(resolve, 2000));
      }
    }
  } catch (error) {
    console.error('Error:', error.message);
  }
}

// Usage
generateImage('a beautiful sunset landscape');
```

### Bash/cURL Batch Generation

```bash
#!/bin/bash

API_URL="http://localhost:5000"
PROMPTS=(
  "a serene mountain landscape"
  "a futuristic city skyline"
  "a cozy forest cabin"
  "an underwater coral reef"
)

for prompt in "${PROMPTS[@]}"; do
  echo "Generating: $prompt"

  # Submit
  response=$(curl -s -X POST "$API_URL/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"prompt\": \"$prompt\", \"steps\": 25}")

  job_id=$(echo "$response" | jq -r '.job_id')
  echo "Job ID: $job_id"

  # Poll status
  while true; do
    status=$(curl -s "$API_URL/api/status/$job_id")
    state=$(echo "$status" | jq -r '.status')

    if [ "$state" = "completed" ]; then
      image=$(echo "$status" | jq -r '.output_image')
      echo "✓ Completed: $image"
      break
    elif [ "$state" = "failed" ]; then
      error=$(echo "$status" | jq -r '.error')
      echo "✗ Failed: $error"
      break
    else
      progress=$(echo "$status" | jq -r '.progress')
      echo "  Progress: $(echo "$progress * 100" | bc)%"
      sleep 2
    fi
  done
done

# List all outputs
echo ""
echo "All generated images:"
curl -s "$API_URL/api/outputs" | jq '.images'
```

---

## Advanced Configuration

### Environment Variables

```bash
# API Server
COMFYUI_HOST=localhost      # ComfyUI host
COMFYUI_PORT=8188           # ComfyUI port
API_HOST=0.0.0.0            # REST API bind address
API_PORT=5000               # REST API port
WORKSPACE_PATH=/workspace   # Workspace directory
DEBUG=false                 # Enable debug logging
```

### Docker Compose Setup

```yaml
version: '3.8'

services:
  comfyui:
    image: ls250824/run-comfyui-image:latest
    ports:
      - "8188:8188"
      - "9000:9000"
    volumes:
      - workspace:/workspace
    environment:
      COMFYUI_VRAM_MODE: HIGH_VRAM

  rest-api:
    build:
      context: .
      dockerfile: api/Dockerfile
    ports:
      - "5000:5000"
    volumes:
      - workspace:/workspace
    environment:
      COMFYUI_HOST: comfyui
      COMFYUI_PORT: 8188
      API_HOST: 0.0.0.0
      API_PORT: 5000
    depends_on:
      - comfyui

volumes:
  workspace:
```

### Nginx Reverse Proxy

```nginx
upstream comfyui {
    server localhost:8188;
}

upstream rest_api {
    server localhost:5000;
}

server {
    listen 80;
    server_name your-domain.com;

    # ComfyUI UI
    location / {
        proxy_pass http://comfyui;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # REST API
    location /api/ {
        proxy_pass http://rest_api;
        proxy_http_version 1.1;
    }
}
```

---

## Error Handling

### Common Errors

**400 Bad Request - Missing Required Field**
```json
{
  "error": "Missing required field: prompt"
}
```
**Solution:** Include `prompt` in request

**404 Not Found - Job Not Found**
```json
{
  "error": "Job not found"
}
```
**Solution:** Verify `job_id` is correct

**503 Service Unavailable - ComfyUI Not Connected**
```json
{
  "status": "unhealthy",
  "error": "ComfyUI not responding"
}
```
**Solution:** Start ComfyUI before REST API

---

## Performance Optimization

### Recommended Settings by GPU

**RTX 4090 (24GB):**
```json
{
  "steps": 25,
  "cfg": 4.0,
  "width": 1024,
  "height": 1024,
  "batch_size": 1
}
```

**RTX 4080 (16GB):**
```json
{
  "steps": 20,
  "cfg": 3.5,
  "width": 768,
  "height": 768,
  "batch_size": 1
}
```

**RTX 3060 (12GB):**
```json
{
  "steps": 20,
  "cfg": 3.5,
  "width": 512,
  "height": 512,
  "batch_size": 1
}
```

### Batch Processing

Process multiple images sequentially:

```python
prompts = [
    "mountain landscape",
    "ocean sunset",
    "forest cabin"
]

for prompt in prompts:
    job_id = generate_and_wait(prompt)
    if job_id:
        print(f"✓ Generated: {job_id}")
```

---

## Troubleshooting

### API Doesn't Start
```bash
# Check ComfyUI is running
curl http://localhost:8188/api/config

# Check Python requirements
pip install flask flask-cors requests

# Start with debug
DEBUG=true python api/comfyui_rest_api.py
```

### Generation Hangs
```bash
# Clear queue
curl -X POST http://localhost:5000/api/queue/clear

# Restart ComfyUI
# Check GPU memory
nvidia-smi
```

### Slow Generation
1. Reduce `steps` (20-24 for Turbo)
2. Lower `width`/`height` (768x768 instead of 1024x1024)
3. Use FP8 models
4. Check GPU isn't throttling (`nvidia-smi`)

---

## References

- **ComfyUI API Docs:** https://docs.comfy.org
- **Flux.2 Turbo Guide:** `docs/provisioning/hf_flux.2_turbo_lora.md`
- **Default Workflow:** `workflows/flux2_turbo_default.json`

