#!/usr/bin/env python3
"""
Download all FLUX.2 models during Docker build for immediate availability.
Run as part of Dockerfile RUN step with HF_TOKEN set.

Models are downloaded to /ComfyUI/models (in container during build).
During pod startup, comfyui-on-workspace.sh moves /ComfyUI → /workspace/ComfyUI,
so models end up in /workspace/ComfyUI/models (persistent volume).
"""

import os
import sys
from pathlib import Path
from huggingface_hub import hf_hub_download
import shutil

# Model definitions: (repo_id, filename, dest_dir, dest_filename)
# Paths use /ComfyUI during Docker build (gets moved to /workspace/ComfyUI at pod startup)
MODELS = [
    ("Comfy-Org/flux2-dev", "split_files/vae/flux2-vae.safetensors", "/ComfyUI/models/vae", "flux2-vae.safetensors"),
    ("Comfy-Org/flux2-dev", "split_files/text_encoders/mistral_3_small_flux2_fp8.safetensors", "/ComfyUI/models/text_encoders", "mistral_3_small_flux2_fp8.safetensors"),
    ("Comfy-Org/flux2-dev", "split_files/diffusion_models/flux2_dev_fp8mixed.safetensors", "/ComfyUI/models/diffusion_models", "flux2_dev_fp8mixed.safetensors"),
    ("ByteZSzn/Flux.2-Turbo-ComfyUI", "Flux2TurboComfyv2.safetensors", "/ComfyUI/models/loras", "Flux2TurboComfyv2.safetensors"),
    ("Comfy-Org/flux2-klein", "split_files/text_encoders/qwen_3_4b.safetensors", "/ComfyUI/models/text_encoders", "qwen_3_4b.safetensors"),
    ("Comfy-Org/flux2-klein", "split_files/diffusion_models/flux-2-klein-base-4b.safetensors", "/ComfyUI/models/diffusion_models", "flux-2-klein-base-4b.safetensors"),
    ("Comfy-Org/flux2-klein", "split_files/diffusion_models/flux-2-klein-4b.safetensors", "/ComfyUI/models/diffusion_models", "flux-2-klein-4b.safetensors"),
]

def download_models():
    """Download all models to their final locations."""
    token = os.environ.get('HF_TOKEN')
    temp_dir = "/tmp/model_download"

    os.makedirs(temp_dir, exist_ok=True)

    total = len(MODELS)
    for idx, (repo_id, filename, dest_dir, dest_filename) in enumerate(MODELS, 1):
        print(f"\n[{idx}/{total}] Downloading {repo_id}/{filename}...")

        try:
            # Create destination directory
            Path(dest_dir).mkdir(parents=True, exist_ok=True)

            # Download to temp directory
            local_file = hf_hub_download(
                repo_id=repo_id,
                filename=filename,
                local_dir=temp_dir,
                repo_type="model",
                token=token,
            )

            # Move to final destination
            final_path = os.path.join(dest_dir, dest_filename)
            if os.path.exists(local_file) and local_file != final_path:
                shutil.move(local_file, final_path)
                print(f"✅ Saved to: {final_path}")
            else:
                print(f"✅ Already at: {final_path}")

        except Exception as e:
            print(f"❌ Failed to download {repo_id}/{filename}: {e}")
            sys.exit(1)

    print(f"\n✅ All {total} models downloaded successfully!")

if __name__ == "__main__":
    download_models()
