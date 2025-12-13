# Run image inference with ComfyUI with provisioning

## Features

- Automatic model and LoRA downloads via environment variables.
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

- The templates on runpod.io are tested on a A40/RTX 5000.
- Avoid using ID's without a region as they are not reliable.

### Runpod.io templates

- 👉 [Runpod Z-Image Turbo](https://console.runpod.io/deploy?template=ia5t70hfak&ref=se4tkc5o)
- 👉 [Runpod Flux.2 Dev](https://console.runpod.io/deploy?template=8nl523gts5&ref=se4tkc5o)

### Hardware requirements

| Model | GPU | VRAM  | RAM |
|-------|-------------------|-------|-------------------------|
| Z-Image Turbo | RTX A5000  | 22Gb | 20Gb           |
| Flux.2 Dev    | A40     | 44Gb | 50Gb           |

## Image documentation

- [Start](https://awesome-comfyui.rozenlaan.site/ComfyUI_image/)

### Workflows

- Open ComfyUI's interface on the left and select template.
- Download from [examples](https://awesome-comfyui.rozenlaan.site/ComfyUI_image_workflows/)

### Image specific tutorial

- [Tutorial](https://awesome-comfyui.rozenlaan.site/ComfyUI_image_tutorial/)


