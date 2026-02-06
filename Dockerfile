################################################################################
# ComfyUI Docker Image - Flux.2 Dev Turbo Edition
################################################################################
# This Dockerfile extends ls250824/run-comfyui-image with:
# - Flux.2 dev turbo workflows
# - Storage optimization for RunPod (fixes /workspace allocation)
# - Pre-downloaded FLUX.2 models (7 models, ~76GB) for zero-wait pod startup
################################################################################

# Build argument for HuggingFace token (required for gated models)
ARG HF_TOKEN=""

FROM ls250824/run-comfyui-image:04022026

WORKDIR /ComfyUI

# ============================================================================
# SECTION 1: ComfyUI Configuration
# ============================================================================
# Copy ComfyUI configurations
COPY configuration/comfy.settings.json user/default/comfy.settings.json
COPY configuration/config.ini user/__manager/config.ini
RUN chmod 644 user/default/comfy.settings.json user/__manager/config.ini

# ============================================================================
# SECTION 2: Model Directory Structure
# ============================================================================
# Ensure model directories exist with proper permissions
RUN mkdir -p /ComfyUI/models/loras && \
    mkdir -p /ComfyUI/models/checkpoints && \
    mkdir -p /ComfyUI/models/text_encoders && \
    mkdir -p /ComfyUI/models/vae && \
    mkdir -p /ComfyUI/models/unet && \
    chmod -R 777 /ComfyUI/models

# ============================================================================
# SECTION 3: Startup Scripts and Documentation
# ============================================================================
# Copy startup scripts with RunPod storage optimization
COPY start.sh onworkspace/comfyui-on-workspace.sh onworkspace/files-on-workspace.sh onworkspace/test-on-workspace.sh onworkspace/docs-on-workspace.sh /
RUN chmod 755 /start.sh /comfyui-on-workspace.sh /files-on-workspace.sh /test-on-workspace.sh /docs-on-workspace.sh

# Copy README and documentation
COPY README.md /README.md
COPY test/ /test
COPY documentation/ /docs
RUN chmod 644 /README.md && chmod -R 644 /test /docs

# ============================================================================
# SECTION 4: Workflows Installation
# ============================================================================
# Copy FLUX.2 workflows to a non-volume location and ComfyUI default directory
# Store in /root/workflows-backup for pod startup to copy to persistent /workspace/workflows
COPY workflows/ /root/workflows-backup/

# Also copy workflows to ComfyUI default workflows directory for immediate loading
RUN mkdir -p /ComfyUI/user/default/workflows && \
    cp /root/workflows-backup/*.json /ComfyUI/user/default/workflows/ 2>/dev/null || true && \
    chmod -R 755 /root/workflows-backup && \
    ls -la /ComfyUI/user/default/workflows/ 2>/dev/null || true

# ============================================================================
# SECTION 6: Workspace Setup and Metadata
# ============================================================================
# Set Workspace
WORKDIR /workspace

# Expose Necessary Ports
# Port 8188: ComfyUI Web UI
# Port 9000: Code-Server (Web IDE)
EXPOSE 8188 9000

# Image Metadata Labels
LABEL org.opencontainers.image.title="ComfyUI - Flux.2 Dev Turbo Edition" \
      org.opencontainers.image.description="ComfyUI image with FLUX.2 dev turbo workflows and RunPod storage optimization" \
      org.opencontainers.image.vendor="ComfyUI Community" \
      org.opencontainers.image.source="https://github.com/maroshi/rundpod-flux2-dev-turbo" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="2.0.0-flux2-turbo" \
      maintainer="ComfyUI Community <noreply@comfyui.org>"

# ============================================================================
# SECTION 7: Entrypoint Configuration
# ============================================================================
# CMD: Default startup command
# Executes /start.sh which handles:
#   1. Storage allocation fix (HF_HUB_CACHE → /workspace)
#   2. GPU/CUDA detection and configuration
#   3. Code-Server startup (port 9000)
#   4. ComfyUI startup (port 8188)
#   5. FLUX.2 model auto-download (~23GB to /workspace)
#
# Environment variables for customization:
#   HF_TOKEN: HuggingFace API token (REQUIRED for FLUX.2-dev gated models)
#   PASSWORD: Code-Server authentication password
#   CIVITAI_API_KEY: CivitAI API key for LoRA downloads
CMD [ "/start.sh" ]
