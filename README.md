# 🚀 Run image with ComfyUI with provisioning — [RunPod.io Deployment](https://runpod.io?ref=se4tkc5o)

[![Docker Image Version](https://img.shields.io/docker/v/ls250824/run-comfyui-image)](https://hub.docker.com/r/ls250824/run-comfyui-image)

![runpod](images/runpod_ZIT.jpg)

A streamlined and automated environment for running **ComfyUI** with **image models**, optimized for use on [RunPod.io](https://runpod.io?ref=se4tkc5o).

For example running Z-Image Turbo on RTX A5000

## 🔧 Features

- Automatic model and LoRA downloads via environment variables.
- Built-in **authentication** for:
  - ComfyUI
  - Code Server
  - Hugging Face API
  - CivitAI API
- Supports advanced workflows for **image generation** and **enhancement** using pre-installed custom nodes.
- Compatible with high-performance NVIDIA GPUs.

## 🧩 Template Deployment

### Deployment.

- All available templates on runpod are tested on a A40/RTX A5000.
- Try to avoid regions US-TX-x as they often fail to download or run the image (Pytorch CUDA mismatch).

### Runpod templates

- 👉 [Runpod Z-Image Turbo](https://console.runpod.io/deploy?template=ia5t70hfak&ref=se4tkc5o)
- 👉 [Runpod Flux.2 Dev](https://console.runpod.io/deploy?template=8nl523gts5&ref=se4tkc5o)

### Documenation

- [Documentation](https://awesome-comfyui.rozenlaan.site/ComfyUI_image/)

### Tutorial

- [Specific for these templates](https://awesome-comfyui.rozenlaan.site/ComfyUI_image_tutorial)

### Workflows

- Open from ComfyUI's interface on the left
- View/Download from [Workflow examples](https://awesome-comfyui.rozenlaan.site/ComfyUI_workflows/)

## 🐳 Docker Images

### Base Images

- **PyTorch Runtime**  [![Docker](https://img.shields.io/docker/v/ls250824/pytorch-cuda-ubuntu-runtime)](https://hub.docker.com/r/ls250824/pytorch-cuda-ubuntu-runtime)

- **ComfyUI Runtime**  [![Docker](https://img.shields.io/docker/v/ls250824/comfyui-runtime)](https://hub.docker.com/r/ls250824/comfyui-runtime)

### Custom Image

```bash
docker pull ls250824/run-comfyui-wan:<version>
```

## 📚 Documentation

- [💻 Hardware Requirements](docs/ComfyUI_image_hardware.md)
- [🧩 Pre-Installed Custom Nodes](docs/ComfyUI_image_custom_nodes.md)
- [📚 Resources](docs/ComfyUI_image_resources.md)
- [📦 Model provisioning](docs/ComfyUI_image_provisioning.md)
- [⚙️ Image setup](docs/ComfyUI_image_image_setup.md)
- [⚙️ Environment variables](docs/ComfyUI_image_configuration.md)

## 🛠️ Build & Push Docker Image (Optional)

Use none docker setup to build the image using the included Python script.

### Build Script: `build-docker.py`

| Argument       | Description                        | Default          |
|----------------|------------------------------------|------------------|
| `--username`   | Your Docker Hub username           | Current user     |
| `--tag`        | Custom image tag                   | Today's date     |
| `--latest`     | Also tag image as `latest`         | Disabled         |

### Example Usage

```bash
git clone https://github.com/jalberty2018/run-comfyui-image.git
cp ./run-comfyui-image/build-docker.py ..

export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

python3 build-docker.py   --username=<your_dockerhub_username>   --tag=<custom_tag>   --latest   run-comfyui-wan
```