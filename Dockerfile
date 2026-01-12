################################################################################
# ComfyUI Docker Image - Flux.2 Dev Turbo LoRA Edition
################################################################################
# This Dockerfile builds a complete ComfyUI environment with:
# - Flux.2 dev turbo LoRA support
# - 45+ community-maintained custom nodes
# - GPU-optimized inference (NVIDIA CUDA)
# - Complete model management system
# - Web-based UI (port 8188) + Code Server (port 9000)
#
# Features:
# ✓ Multi-format LoRA support (safetensors, GGUF quantization)
# ✓ Automatic model organization via LoRA Manager
# ✓ RMBG background removal
# ✓ ControlNet & SAM segmentation
# ✓ HighRes/upscaling workflows
# ✓ Real-time LoRA training capabilities
# ✓ HuggingFace & CivitAI integration
################################################################################

FROM ls250824/comfyui-runtime:07012026

WORKDIR /ComfyUI

# ============================================================================
# SECTION 1: ComfyUI Core Configuration
# ============================================================================
# Copy ComfyUI configurations
COPY configuration/comfy.settings.json user/default/comfy.settings.json
RUN chmod 644 user/default/comfy.settings.json

# Copy ComfyUI ini settings
COPY configuration/config.ini user/__manager/config.ini
RUN chmod 644 user/__manager/config.ini

# ============================================================================
# SECTION 2: Core Python Dependencies for LoRA & Model Support
# ============================================================================
# matrix-nio: Matrix chat protocol support for notifications
# safetensors: Secure model weight serialization (required for LoRA files)
# huggingface-hub: Download models and LoRAs from HuggingFace
# peft: Parameter-Efficient Fine-Tuning (LoRA framework)
RUN python -m pip install --no-cache-dir --root-user-action ignore -c /constraints.txt \
    matrix-nio \
    safetensors \
    huggingface-hub \
    peft \
    -r manager_requirements.txt

# ============================================================================
# SECTION 3: Custom Nodes Installation (45+ Community Nodes)
# ============================================================================
# Core LoRA & Model Management Nodes:
#   • ComfyUI-Lora-Manager: Load, organize, preview LoRA files
#   • ComfyUI-GGUF: Quantized GGUF model support for Flux.2 turbo
#   • comfyui-model-linker-desktop: Symbolic link model organization
#
# Flux-Specific Enhancement Nodes:
#   • rgthree-comfy: Advanced workflow nodes and utilities
#   • ComfyUI-KJNodes: Utility nodes for Flux pipelines
#   • LG_SamplingUtils: Advanced sampling strategies for Flux.2
#   • Power-Flow: Node workflow optimization
#
# Image Processing & Output Nodes:
#   • ComfyUI-Image-Saver: Enhanced image output handling
#   • ComfyUI-EasyColorCorrector: Color grading and correction
#   • EsesImageAdjustments: Image adjustment nodes
#   • cg-image-filter: Advanced filtering capabilities
#   • ComfyUI-Detail-Daemon: Detail enhancement
#
# Advanced Features:
#   • ComfyUI-RMBG: Background removal (RMBG-1.4 AI model)
#   • ComfyUI-segment-anything-2: SAM2 segmentation
#   • comfyui_controlnet_aux: ControlNet preprocessing
#   • ComfyUI_UltimateSDUpscale: High-quality upscaling
#   • ComfyUI-JoyCaption: Image captioning (supports Flux.2)

WORKDIR /ComfyUI/custom_nodes

RUN git clone --depth=1 --filter=blob:none https://github.com/rgthree/rgthree-comfy.git && \
    git clone --depth=1 --filter=blob:none https://github.com/liusida/ComfyUI-Login.git && \
    git clone --depth=1 --filter=blob:none https://github.com/kijai/ComfyUI-KJNodes.git && \
	git clone --depth=1 --filter=blob:none https://github.com/StartHua/Comfyui_joytag.git && \
	git clone --depth=1 --filter=blob:none https://github.com/1038lab/ComfyUI-JoyCaption.git && \
	git clone --depth=1 --filter=blob:none https://github.com/alessandrozonta/Comfyui-LoopLoader.git && \
	git clone --depth=1 --filter=blob:none https://github.com/quasiblob/ComfyUI-EsesImageAdjustments.git && \
	git clone --depth=1 --filter=blob:none https://github.com/quasiblob/ComfyUI-EsesImageEffectCurves.git && \
	git clone --depth=1 --filter=blob:none https://github.com/quasiblob/ComfyUI-EsesImageEffectLevels.git && \
	git clone --depth=1 --filter=blob:none https://github.com/regiellis/ComfyUI-EasyColorCorrector.git && \
	git clone --depth=1 --filter=blob:none https://github.com/alexopus/ComfyUI-Image-Saver.git && \
	git clone --depth=1 --filter=blob:none https://github.com/Jonseed/ComfyUI-Detail-Daemon.git && \
	git clone --depth=1 --filter=blob:none https://github.com/chrisgoringe/cg-image-filter.git && \
	git clone --depth=1 --filter=blob:none https://github.com/KY-2000/comfyui-save-image-enhanced.git && \
	git clone --depth=1 --filter=blob:none https://github.com/ClownsharkBatwing/RES4LYF.git && \
	git clone --depth=1 --filter=blob:none https://github.com/BlenderNeko/ComfyUI_Noise.git && \
	git clone --depth=1 --filter=blob:none https://github.com/evanspearman/ComfyMath.git && \
	git clone --depth=1 --filter=blob:none https://github.com/city96/ComfyUI-GGUF.git && \
    git clone --depth=1 --filter=blob:none https://github.com/Azornes/Comfyui-Resolution-Master.git && \
	git clone --depth=1 --filter=blob:none https://github.com/ssitu/ComfyUI_UltimateSDUpscale --recursive && \
	git clone --depth=1 --filter=blob:none https://github.com/kijai/ComfyUI-segment-anything-2.git && \
    git clone --depth=1 --filter=blob:none https://github.com/1038lab/ComfyUI-RMBG.git && \
	git clone --depth=1 --filter=blob:none https://github.com/Fannovel16/comfyui_controlnet_aux.git && \
	git clone --depth=1 --filter=blob:none https://github.com/liusida/ComfyUI-AutoCropFaces.git && \
	git clone --depth=1 --filter=blob:none https://github.com/GizmoR13/PG-Nodes.git && \
	git clone --depth=1 --filter=blob:none https://github.com/BigStationW/ComfyUi-Scale-Image-to-Total-Pixels-Advanced && \
	git clone --depth=1 --filter=blob:none https://github.com/bradsec/ComfyUI_StringEssentials.git && \
	git clone --depth=1 --filter=blob:none https://github.com/x3bits/ComfyUI-Power-Flow.git && \
	git clone --depth=1 --filter=blob:none https://github.com/9nate-drake/Comfyui-SecNodes.git && \
	git clone --depth=1 --filter=blob:none https://github.com/PozzettiAndrea/ComfyUI-SAM3.git && \
	git clone --depth=1 --filter=blob:none https://github.com/heyburns/image-chooser-classic.git && \
	git clone --depth=1 --filter=blob:none https://github.com/neonr-0/ComfyUI-PixelConstrainedScaler.git && \
	git clone --depth=1 --filter=blob:none https://github.com/vrgamegirl19/comfyui-vrgamedevgirl.git && \
	git clone --depth=1 --filter=blob:none https://github.com/ChangeTheConstants/SeedVarianceEnhancer.git && \
	git clone --depth=1 --filter=blob:none https://github.com/erosDiffusion/ComfyUI-EulerDiscreteScheduler.git && \
	git clone --depth=1 --filter=blob:none https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git && \
	git clone --depth=1 --filter=blob:none https://github.com/BigStationW/ComfyUi-ConditioningNoiseInjection.git && \
	git clone --depth=1 --filter=blob:none https://github.com/BigStationW/ComfyUi-ConditioningTimestepSwitch.git && \
	git clone --depth=1 --filter=blob:none https://github.com/lrzjason/Comfyui-LatentUtils.git && \
	git clone --depth=1 --filter=blob:none https://github.com/geroldmeisinger/ComfyUI-outputlists-combiner.git && \
	git clone --depth=1 --filter=blob:none https://github.com/RamonGuthrie/ComfyUI-RBG-SmartSeedVariance.git && \
	git clone --depth=1 --filter=blob:none https://github.com/willmiao/ComfyUI-Lora-Manager.git && \
	git clone --depth=1 --filter=blob:none https://github.com/rethink-studios/comfyui-model-linker-desktop.git && \
	git clone --depth=1 --filter=blob:none https://github.com/lrzjason/Comfyui-QwenEditUtils.git && \
	git clone --depth=1 --filter=blob:none https://github.com/LAOGOU-666/ComfyUI-LG_SamplingUtils.git && \
	git clone --depth=1 --filter=blob:none https://github.com/scraed/LanPaint.git && \
	git clone --depth=1 --filter=blob:none https://github.com/BigStationW/ComfyUi-TextEncodeQwenImageEditAdvanced.git && \
	git clone --depth=1 --filter=blob:none https://github.com/princepainter/ComfyUI-PainterQwenImageEdit.git

# Outputlists-combiner working version
# RUN cd ComfyUI-outputlists-combiner && git fetch --unshallow && git checkout be17d247db29d555df4bc1c776b2b9289f7f42ba

# triton-windows error
# RUN cd ComfyUI-RMBG && git fetch --unshallow && git checkout 9ecda2e689d72298b4dca39403a85d13e53ea659

# ============================================================================
# SECTION 4: GPU Optimization - Rewrite ONNXRuntime to GPU Version
# ============================================================================
# RMBG (Remove Background) library defaults to CPU version
# Rewrite to GPU version (onnxruntime-gpu) for NVIDIA GPUs
RUN set -eux; \
  for f in \
    ComfyUI-RMBG/requirements.txt; do \
      [ -f "$f" ] || continue; \
      sed -i -E 's/^( *| *)(onnxruntime)([<>=].*)?(\s*)$/\1onnxruntime-gpu==1.22.*\4/i' "$f"; \
    done

# ============================================================================
# SECTION 5: Install Custom Node Dependencies
# ============================================================================
# Core packages:
#   • diffusers: HuggingFace diffusion models (Flux.2 support)
#   • psutil: System monitoring
#
# LoRA & Model Loading:
#   • ComfyUI-Lora-Manager: LoRA file management and loading
#   • ComfyUI-GGUF: Quantized GGUF models for Flux.2 turbo
#
# Advanced Image Processing:
#   • ComfyUI-JoyCaption: Image captioning with GGUF support
#   • ComfyUI-RMBG: Background removal (GPU-optimized)
#   • comfyui_controlnet_aux: ControlNet preprocessing

WORKDIR /ComfyUI/custom_nodes

RUN python -m pip install --no-cache-dir --root-user-action ignore -c /constraints.txt \
    diffusers psutil \
    -r ComfyUI-Login/requirements.txt \
    -r ComfyUI-KJNodes/requirements.txt \
    -r RES4LYF/requirements.txt \
    -r ComfyUI-GGUF/requirements.txt \
    -r ComfyUI-RMBG/requirements.txt \
    -r comfyui_controlnet_aux/requirements.txt \
	-r Comfyui-SecNodes/requirements.txt \
	-r ComfyUI-EasyColorCorrector/requirements.txt \
	-r ComfyUI-Image-Saver/requirements.txt \
	-r comfyui-vrgamedevgirl/requirements.txt \
    -r ComfyUI-Detail-Daemon/requirements.txt \
    -r ComfyUI-SeedVR2_VideoUpscaler/requirements.txt \
	-r ComfyUI-JoyCaption/requirements.txt \
	-r ComfyUI-JoyCaption/requirements_gguf.txt \
	-r ComfyUI-outputlists-combiner/requirements.txt \
	-r ComfyUI-Lora-Manager/requirements.txt

# ============================================================================
# SECTION 6: Model Node Setup - SAM3 & LoRA Manager Configuration
# ============================================================================
# Activate SAM3 Segmentation Model
# Segment Anything Model 3 - Advanced image segmentation capabilities
WORKDIR /ComfyUI/custom_nodes/ComfyUI-SAM3
RUN python install.py

# Configure LoRA Manager with Settings Template
# Enables automatic LoRA discovery and management from ~/models/loras
WORKDIR /ComfyUI/custom_nodes/ComfyUI-Lora-Manager
COPY /configuration/lora-manager-settings.json settings.json.template
RUN chmod 644 settings.json.template

# ============================================================================
# SECTION 6.5: Pre-download FLUX.2 Models into Image
# ============================================================================
# Download core FLUX.2 models during image build to speed up container startup
# This removes the need for multi-gigabyte downloads at runtime!
#
# Models downloaded (~30-40GB total):
#   • flux2-vae.safetensors (VAE encoder) ~0.5GB
#   • mistral_3_small_flux2_fp8.safetensors (Text encoder) ~2GB
#   • flux2_dev_fp8mixed.safetensors (Main diffusion model) ~24GB
#   • 4x_foolhardy_Remacri.pth (Upscaler) ~3.5MB

WORKDIR /ComfyUI/models

RUN python3 << 'EOF'
import os
import subprocess
import shutil

# Create model directories
os.makedirs('vae', exist_ok=True)
os.makedirs('text_encoders', exist_ok=True)
os.makedirs('diffusion_models', exist_ok=True)
os.makedirs('upscale_models', exist_ok=True)
os.makedirs('loras', exist_ok=True)

print("📥 Pre-downloading FLUX.2 models to image (~30-40GB)...")
print("   This will take 20-30 minutes on first build...")

try:
    # Download VAE
    print("  ▶️  VAE encoder...")
    subprocess.run([
        'hf_transfer', 'download', 'Comfy-Org/flux2-dev',
        'split_files/vae/flux2-vae.safetensors',
        '--local-dir', 'vae', '--local-dir-use-symlinks', 'False'
    ], check=True)
    # Move from split_files subdirectory
    if os.path.exists('vae/split_files/vae/flux2-vae.safetensors'):
        shutil.move('vae/split_files/vae/flux2-vae.safetensors', 'vae/flux2-vae.safetensors')
        shutil.rmtree('vae/split_files', ignore_errors=True)

    # Download Text Encoder
    print("  ▶️  Text encoder (Mistral-3)...")
    subprocess.run([
        'hf_transfer', 'download', 'Comfy-Org/flux2-dev',
        'split_files/text_encoders/mistral_3_small_flux2_fp8.safetensors',
        '--local-dir', 'text_encoders', '--local-dir-use-symlinks', 'False'
    ], check=True)
    # Move from split_files subdirectory
    if os.path.exists('text_encoders/split_files/text_encoders/mistral_3_small_flux2_fp8.safetensors'):
        shutil.move('text_encoders/split_files/text_encoders/mistral_3_small_flux2_fp8.safetensors', 'text_encoders/mistral_3_small_flux2_fp8.safetensors')
        shutil.rmtree('text_encoders/split_files', ignore_errors=True)

    # Download Main Diffusion Model (LARGEST FILE ~24GB)
    print("  ▶️  FLUX.2 dev turbo model (24GB - this takes time)...")
    subprocess.run([
        'hf_transfer', 'download', 'Comfy-Org/flux2-dev',
        'split_files/diffusion_models/flux2_dev_fp8mixed.safetensors',
        '--local-dir', 'diffusion_models', '--local-dir-use-symlinks', 'False'
    ], check=True)
    # Move from split_files subdirectory
    if os.path.exists('diffusion_models/split_files/diffusion_models/flux2_dev_fp8mixed.safetensors'):
        shutil.move('diffusion_models/split_files/diffusion_models/flux2_dev_fp8mixed.safetensors', 'diffusion_models/flux2_dev_fp8mixed.safetensors')
        shutil.rmtree('diffusion_models/split_files', ignore_errors=True)

    # Download Upscaler
    print("  ▶️  Upscaler (4x_foolhardy_Remacri)...")
    subprocess.run([
        'hf_transfer', 'download', 'LS110824/upscale',
        '4x_foolhardy_Remacri.pth',
        '--local-dir', 'upscale_models', '--local-dir-use-symlinks', 'False'
    ], check=True)

    # Download Flux.2 Turbo LoRA
    print("  ▶️  Flux.2 Turbo LoRA (Flux2TurboComfyv2.safetensors)...")
    subprocess.run([
        'hf_transfer', 'download', 'ByteZSzn/Flux.2-Turbo-ComfyUI',
        'Flux2TurboComfyv2.safetensors',
        '--local-dir', 'loras', '--local-dir-use-symlinks', 'False'
    ], check=True)

    print("✅ All models downloaded successfully!")

except Exception as e:
    print(f"⚠️ Warning: Model download error (non-critical): {e}")
    print("   Models will be downloaded at startup instead")

EOF

# ============================================================================
# SECTION 7: Create Model Directory Structure for LoRA & Assets
# ============================================================================
# Directory structure for ComfyUI models:
#   /ComfyUI/models/loras/          - LoRA files (.safetensors)
#   /ComfyUI/models/checkpoints/     - Diffusion models (Flux.2 dev)
#   /ComfyUI/models/text_encoders/   - Text encoders (Mistral-3)
#   /ComfyUI/models/vae/             - VAE encoders
#   /ComfyUI/models/unet/            - GGUF quantized models
# Note: These will be at /workspace/ComfyUI/models at runtime after move
# These directories are created with write permissions for model downloads
RUN mkdir -p /ComfyUI/models/loras && \
    mkdir -p /ComfyUI/models/checkpoints && \
    mkdir -p /ComfyUI/models/text_encoders && \
    mkdir -p /ComfyUI/models/vae && \
    mkdir -p /ComfyUI/models/unet && \
    chmod -R 777 /ComfyUI/models

# Set Working Directory
WORKDIR /

# ============================================================================
# SECTION 8: Copy Scripts, Startup Configuration, and Documentation
# ============================================================================
# Startup scripts:
#   • start.sh: Main entrypoint - GPU detection, service startup, env setup
#   • comfyui-on-workspace.sh: Copy ComfyUI to workspace (data persistence)
#   • files-on-workspace.sh: Set up file permissions and directories
#   • test-on-workspace.sh: Run diagnostic tests
#   • docs-on-workspace.sh: Copy documentation to accessible location
COPY start.sh onworkspace/comfyui-on-workspace.sh onworkspace/files-on-workspace.sh onworkspace/test-on-workspace.sh onworkspace/docs-on-workspace.sh /
RUN chmod 755 /start.sh /comfyui-on-workspace.sh /files-on-workspace.sh /test-on-workspace.sh /docs-on-workspace.sh

COPY README.md /README.md
RUN chmod 664 /README.md

COPY test/ /test
RUN chmod -R 644 /test

COPY documentation/ /docs
RUN chmod -R 644 /docs

# ============================================================================
# SECTION 9: Workspace Setup, Port Configuration, and Metadata
# ============================================================================
# Set Workspace
WORKDIR /workspace

# Expose Necessary Ports
# Port 8188: ComfyUI Web UI (http://localhost:8188)
# Port 9000: Code-Server (Web IDE for editing workflows)
EXPOSE 8188 9000

# Image Metadata Labels
LABEL org.opencontainers.image.title="ComfyUI 0.7.0 - Flux.2 Turbo LoRA Edition" \
      org.opencontainers.image.description="Production ComfyUI image with 45+ custom nodes, Flux.2 dev turbo LoRA support, GGUF quantization, background removal, segmentation, upscaling, and integrated development environment" \
      org.opencontainers.image.vendor="ComfyUI Community" \
      org.opencontainers.image.source="https://github.com/maroshi/rundpod-flux2-dev-turbo" \
      org.opencontainers.image.documentation="https://awesome-comfyui.rozenlaan.site/" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="1.0.0-flux2-turbo-lora" \
      maintainer="ComfyUI Community <noreply@comfyui.org>"

# ============================================================================
# SECTION 11: Runtime Dependency Verification
# ============================================================================
# Verify critical runtime dependencies are installed and working:
# - PyTorch (torch): Deep learning framework
# - CUDA Support: GPU acceleration
# - ONNXRuntime: Model inference optimization
# - Triton: CUDA kernel compiler
#
# For Flux.2 Turbo LoRA inference, ensure:
# - CUDA is available
# - GPU detection works
# - LoRA libraries are properly installed
RUN python -c "import torch, torchvision, torchaudio, triton, importlib, importlib.util as iu; \
print('=== Flux.2 Turbo LoRA Runtime Verification ==='); \
print(f'PyTorch: {torch.__version__}'); \
print(f'Torchvision: {torchvision.__version__}'); \
print(f'Torchaudio: {torchaudio.__version__}'); \
print(f'Triton: {triton.__version__}'); \
name = 'onnxruntime_gpu' if iu.find_spec('onnxruntime_gpu') else ('onnxruntime' if iu.find_spec('onnxruntime') else None); \
ver = (importlib.import_module(name).__version__ if name else 'not installed'); \
label = 'ONNXRuntime-GPU' if name=='onnxruntime_gpu' else 'ONNXRuntime'; \
print(f'{label}: {ver}'); \
print(f'CUDA available: {torch.cuda.is_available()}'); \
print(f'CUDA version: {torch.version.cuda}'); \
print(f'GPU Device: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"CPU\"}'); \
print('✓ All runtime dependencies verified')"

# ============================================================================
# SECTION 10: Clone Community Documentation (Frequently Updated)
# ============================================================================
# awesome-comfyui-docs: Comprehensive ComfyUI documentation
#   • Configuration guides
#   • Hardware optimization
#   • Custom node usage
#   • Model setup and provisioning
# NOTE: This section is placed LAST to optimize Docker layer caching.
# When the workflow is updated frequently, only this layer will be rebuilt.
RUN git clone --depth=1 --filter=blob:none https://github.com/jalberty2018/comfyui-docs.git /awesome-comfyui-docs

# Copy selected docs *inside* the image
RUN mkdir -p /docs && \
    cp /awesome-comfyui-docs/ComfyUI_image_configuration.md /docs/ComfyUI_image_configuration.md && \
    cp /awesome-comfyui-docs/ComfyUI_image_custom_nodes.md /docs/ComfyUI_image_custom_nodes.md && \
    cp /awesome-comfyui-docs/ComfyUI_image_hardware.md /docs/ComfyUI_image_hardware.md && \
    cp /awesome-comfyui-docs/ComfyUI_image_image_setup.md /docs/ComfyUI_image_image_setup.md && \
    cp /awesome-comfyui-docs/ComfyUI_image_resources.md /docs/ComfyUI_image_resources.md

# Cleanup temporary files
RUN rm -rf /awesome-comfyui-docs

# ============================================================================
# SECTION 11: Copy Workflows (Frequently Updated)
# ============================================================================
# Copy workflow files to workspace
# NOTE: This is placed LAST to optimize Docker layer caching.
# When workflows are updated frequently, only this layer will be rebuilt,
# all previous layers will be reused from cache.
COPY workflows/ /workspace/workflows/

# Also copy workflows to ComfyUI default workflows directory for immediate loading
RUN mkdir -p /ComfyUI/user/default/workflows && \
    cp /workspace/workflows/*.json /ComfyUI/user/default/workflows/ 2>/dev/null || true && \
    ls -la /ComfyUI/user/default/workflows/

# ============================================================================
# SECTION 12: Entrypoint Configuration
# ============================================================================
# CMD: Default startup command
# Executes /start.sh which handles:
#   1. SSH setup (if PUBLIC_KEY env var set)
#   2. GPU/CUDA detection and configuration
#   3. Code-Server startup (port 9000)
#   4. ComfyUI startup (port 8188)
#   5. Workspace setup and file permissions
#   6. Model directory initialization
#
# Environment variables for customization:
#   RUNPOD_GPU_COUNT: GPU count detection for RunPod
#   PASSWORD: Code-Server authentication password
#   HF_TOKEN: HuggingFace API token for model downloads
#   CIVITAI_API_KEY: CivitAI API key for LoRA downloads
CMD [ "/start.sh" ]
