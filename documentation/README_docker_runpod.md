# Run image inference with ComfyUI with provisioning

## Features

- Automatic model and LoRA downloads via environment variables or lora manager.
- Supports advanced workflows for **image generation** and **enhancement** using pre-installed custom nodes.
- Compatible with high-performance NVIDIA GPUs (CUDA 12.8).
- Compiled attentions and GPU accelerations.

## Built-in **authentication**
  
- ComfyUI
- Code Server
- HuggingFace API
- CivitAI API

## Images on Docker 

- If the image is **less then one day old** it is possible that it is not stable and will be updated.

## Template Deployment

### Deployment/Usage information

- The templates on runpod.io are tested on a RTX 6000,5000,4500.
- Avoid using ID's without a region as they are not reliable.

### Runpod templates

- 👉 [Runpod Z-Image Turbo](https://console.runpod.io/deploy?template=ia5t70hfak&ref=se4tkc5o)
- 👉 [Runpod Flux.2 Dev](https://console.runpod.io/deploy?template=8nl523gts5&ref=se4tkc5o)
- 👉 [Runpod Qwen image edit 2511](https://console.runpod.io/deploy?template=mxvvx0hcmp&ref=se4tkc5o)

### Hardware requirements

| Model           | Tested GPU          | Min VRAM | Min RAM |
|-----------------|---------------------|----------|---------|
| Z-Image Turbo   | RTX A5000, A4500    | 22 GB    | 50 GB   |
| Flux.2 Dev      | RTX A6000           | 44 GB    | 50 GB   |
| Qwen            | RTX A6000           | 44 GB    | 65 GB   |

| Component       | Model | Minimum                    |
|-----------------|-------|----------------------------|
| Volume Storage  | ZIT   | 50 GB (`/workspace`)       |
| Volume Storage  | Flux  | 90 GB (`/workspace`)       |
| Volume Storage  | Qwen  | 70 GB (`/workspace`)       |
| Pod Storage     | —     | 15 GB                      |

## Image documentation

- [Start](https://awesome-comfyui.rozenlaan.site/ComfyUI_image/)
- [Tutorial](https://awesome-comfyui.rozenlaan.site/ComfyUI_image_tutorial/)

### Workflows

- Open ComfyUI's interface on the left and select template.
- Download from [examples](https://awesome-comfyui.rozenlaan.site/ComfyUI_image_workflows/)




