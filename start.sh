#!/bin/bash
echo "▶️ Pod run-comfyui-image started"
echo "ℹ️ Wait until the message 🎉 Provisioning done, ready to create AI content 🎉 is displayed"

# Enable SSH if PUBLIC_KEY is set
if [[ -n "$PUBLIC_KEY" ]]; then
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    service ssh start
    echo "✅ [SSH enabled]"
fi

# Configure SSH for passwordless root access
echo "ℹ️ Configuring SSH for passwordless root access"

# 1. Add config parameters
cat >> /etc/ssh/sshd_config << 'EOF'

PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords yes
UsePAM no
ChallengeResponseAuthentication no
EOF

# 2. Remove root password (critical step)
passwd -d root

# 3. Restart SSH
service ssh restart

echo "✅ [SSH configured for passwordless root access]"

# Export env variables
if [[ -n "${RUNPOD_GPU_COUNT:-}" ]]; then
   echo "ℹ️ Exporting runpod.io environment variables..."
   printenv | grep -E '^RUNPOD_|^PATH=|^_=' \
     | awk -F = '{ print "export " $1 "=\"" $2 "\"" }' >> /etc/rp_environment

   echo 'source /etc/rp_environment' >> ~/.bashrc
fi

# Move necessary files to workspace
echo "ℹ️ [Moving necessary files to workspace] enabling rebooting pod without data loss"
for script in comfyui-on-workspace.sh files-on-workspace.sh test-on-workspace.sh docs-on-workspace.sh; do
    if [ -f "/$script" ]; then
        echo "Executing $script..."
        "/$script"
    else
        echo "⚠️ WARNING: Skipping $script (not found)"
    fi
done

# Create output directory for cloud transfer
mkdir -p /workspace/output/

# Set optimizations
export PYTORCH_ALLOC_CONF=expandable_segments:True,garbage_collection_threshold:0.8
export COMFYUI_VRAM_MODE=HIGH_VRAM

# GPU detection
echo "ℹ️ Testing GPU/CUDA provisioning"

# GPU detection Runpod.io
HAS_GPU_RUNPOD=0
if [[ -n "${RUNPOD_GPU_COUNT:-}" && "${RUNPOD_GPU_COUNT:-0}" -gt 0 ]]; then
  HAS_GPU_RUNPOD=1
  echo "✅ [GPU DETECTED] Found via RUNPOD_GPU_COUNT=${RUNPOD_GPU_COUNT}"
else
  echo "⚠️ [NO GPU] No Runpod.io GPU detected."
fi  

# GPU detection nvidia-smi
HAS_GPU=0
if command -v nvidia-smi >/dev/null 2>&1; then
  if nvidia-smi >/dev/null 2>&1; then
    HAS_GPU=1
    GPU_MODEL=$(nvidia-smi --query-gpu=name --format=csv,noheader | xargs | sed 's/,/, /g')
    echo "✅ [GPU DETECTED] Found via nvidia-smi → Model(s): ${GPU_MODEL}"
  else
    echo "⚠️ [NO GPU] nvidia-smi found but failed to run (driver or permission issue)"
  fi
else
  echo "⚠️ [NO GPU] No GPU found via nvidia-smi"
fi

# Start code-server (HTTP port 9000) 
if [[ "$HAS_GPU" -eq 1 || "$HAS_GPU_RUNPOD" -eq 1 ]]; then    
    echo "▶️ Code-Server service starting"
	
    if [[ -n "$PASSWORD" ]]; then
        code-server /workspace --auth password --disable-update-check --disable-telemetry --host 0.0.0.0 --bind-addr 0.0.0.0:9000 &
    else
        echo "⚠️ PASSWORD is not set as an environment. Password file: /root/.config/code-server/config.yaml"
        code-server /workspace --disable-telemetry --disable-update-check --host 0.0.0.0 --bind-addr 0.0.0.0:9000 &
    fi
	
    echo "🎉 code-server service started"
else
    echo "⚠️ WARNING: No GPU available, Code Server not started to limit memory use"
fi
	
sleep 2

# Python, Torch CUDA check
HAS_CUDA=0
if command -v python >/dev/null 2>&1; then
  if python - << 'PY' >/dev/null 2>&1
import sys
try:
    import torch
    sys.exit(0 if torch.cuda.is_available() else 1)
except Exception:
    sys.exit(1)
PY
  then
    HAS_CUDA=1
  fi
else
  echo "⚠️ Python not found – assuming no CUDA"
fi

# Export generation configuration before starting ComfyUI
export OUTPUT_FOLDER="/workspace/output/"
export GENERATION_LOG_DIR="/workspace/logs/generations/"
export PROMPT_DEFAULT_TEXT="kong fu panda, dancing and playing concert flute, in circus arean, crowd cheering, music notes emrge from the flute"
export IMAGE_DEFAULT_ID="UNDEFINED_ID_"

# Persist custom env variables for SSH sessions
cat >> /etc/rp_environment << 'EOF'
export OUTPUT_FOLDER="/workspace/output/"
export GENERATION_LOG_DIR="/workspace/logs/generations/"
export PROMPT_DEFAULT_TEXT="kong fu panda, dancing and playing concert flute, in circus arean, crowd cheering, music notes emrge from the flute"
export IMAGE_DEFAULT_ID="UNDEFINED_ID_"
EOF

# Start ComfyUI (HTTP port 8188)
HAS_COMFYUI=0

if [[ "$HAS_CUDA" -eq 1 ]]; then

	SETTINGS_DIR="/workspace/ComfyUI/custom_nodes/ComfyUI-Lora-Manager"
	SETTINGS_FILE="$SETTINGS_DIR/settings.json"
	TEMPLATE_FILE="$SETTINGS_DIR/settings.json.template"
	
	mkdir -p "$SETTINGS_DIR"
	
	if [[ -n "${CIVITAI_TOKEN:-}" ]]; then
	    echo "ℹ️ Injecting CIVITAI_TOKEN into ComfyUI-Lora-Manager"
	
	    jq --arg token "$CIVITAI_TOKEN" \
	       '.civitai_api_key = $token' \
	       "$TEMPLATE_FILE" > "$SETTINGS_FILE"
	else
	    echo "⚠️ CIVITAI_TOKEN not set – Insert your token manually in ComfyUI-Lora-Manager"
	fi
	
    # Remove authentication custom nodes if DISABLE_AUTH is set (default: true)
    if [[ "${DISABLE_AUTH:-true}" == "true" ]]; then
        echo "🔓 Disabling authentication (set DISABLE_AUTH=false to enable)"
        rm -rf /workspace/ComfyUI/custom_nodes/ComfyUI-Login 2>/dev/null || true
        rm -rf /workspace/ComfyUI/custom_nodes/ComfyUI-Basic-Auth 2>/dev/null || true
        rm -rf /workspace/ComfyUI/custom_nodes/comfyui-basic-auth 2>/dev/null || true
    else
        echo "🔒 Authentication enabled"
    fi

	echo "▶️ ComfyUI service starting (CUDA available)"

    python3 /workspace/ComfyUI/main.py ${COMFYUI_EXTRA_ARGUMENTS:---listen --enable-manager --preview-method auto} &

    # Wait until ComfyUI is ready
    MAX_TRIES=40
    COUNT=0
		
    until curl -s http://127.0.0.1:8188 > /dev/null; do
        COUNT=$((COUNT+1))

        if [[ $COUNT -ge $MAX_TRIES ]]; then
            echo "⚠️  WARNING: ComfyUI is still not responding after $MAX_TRIES attempts (~1 min)."
            echo "⚠️  Continuing script anyway..."
            break
        fi

        echo "ℹ️ Waiting for ComfyUI to come online... ($COUNT/$MAX_TRIES)"
        sleep 5
    done

    # Success message only when ComfyUI responded
    if curl -s http://127.0.0.1:8188 > /dev/null; then
        HAS_COMFYUI=1
        echo "🎉 ComfyUI is online!"
    fi
else
    echo "❌ ERROR: PyTorch CUDA driver mismatch or unavailable, ComfyUI not started"
fi

# Function to download models if variables are set
download_model_HF() {
    local model_var="$1"
    local file_var="$2"
    local dest_dir="$3"

    if [[ -n "${!model_var}" && -n "${!file_var}" ]]; then
        local target="/workspace/ComfyUI/models/$dest_dir"
        mkdir -p "$target"

        # Check if file already exists (including in subdirectories)
        local filename=$(basename "${!file_var}")
        if find "$target" -name "$filename" -o -name "*.safetensors" -o -name "*.pth" 2>/dev/null | grep -q .; then
            echo "✅ [SKIP] ${filename} already exists in $target"
            return 0
        fi

        echo "ℹ️ [DOWNLOAD] Fetching ${!model_var}/${!file_var} → $target"
        python3 - <<PYTHON_HF 2>/dev/null
import os
import shutil
import glob
from huggingface_hub import hf_hub_download

try:
    token = os.environ.get('HF_TOKEN')
    temp_dir = "/workspace/temp"

    local_file = hf_hub_download(
        repo_id="${!model_var}",
        filename="${!file_var}",
        local_dir=temp_dir,
        repo_type="model",
        token=token,
        cache_dir=os.environ.get('HF_HUB_CACHE', '/workspace/.cache/huggingface')
    )

    # Move to final destination, flattening path (remove any nested directories)
    final_filename = os.path.basename("${!file_var}")
    final_path = os.path.join("$target", final_filename)
    os.makedirs(os.path.dirname(final_path), exist_ok=True)

    if os.path.exists(local_file) and local_file != final_path:
        shutil.move(local_file, final_path)

    # Also search for the file in nested directories if not found yet
    if not os.path.exists(final_path):
        found_files = glob.glob(os.path.join(temp_dir, '**', final_filename), recursive=True)
        if found_files:
            shutil.move(found_files[0], final_path)

except Exception as e:
    print(f"⚠️ Failed to download ${!model_var}/${!file_var}: {e}")
PYTHON_HF
        sleep 1
    fi

    return 0
}

download_generic_HF() {
    local model_var="$1"
    local file_var="$2"
    local dest_dir="$3"

    local model="${!model_var}"
    [[ -z "$model" ]] && return 0

    local file=""
    if [[ -n "$file_var" ]]; then
        file="${!file_var}"
    fi

    local target="/workspace/ComfyUI/$dest_dir"
    mkdir -p "$target"

    # Check if files already exist in target directory
    if [[ -n "$(find "$target" -type f \( -name "*.safetensors" -o -name "*.pth" -o -name "*.bin" \) 2>/dev/null | head -1)" ]]; then
        echo "✅ [SKIP] Models already exist in $target"
        return 0
    fi

    if [[ -n "$file" ]]; then
        echo "ℹ️ [DOWNLOAD] Fetching $model/$file → $target"
        python3 - <<PYTHON_HF 2>/dev/null
import os
import shutil
import glob
from huggingface_hub import hf_hub_download

try:
    token = os.environ.get('HF_TOKEN')
    temp_dir = "/workspace/temp"

    local_file = hf_hub_download(
        repo_id="$model",
        filename="$file",
        local_dir=temp_dir,
        repo_type="model",
        token=token,
        cache_dir=os.environ.get('HF_HUB_CACHE', '/workspace/.cache/huggingface')
    )

    # Move to final destination, flattening path (remove any nested directories)
    final_filename = os.path.basename("$file")
    final_path = os.path.join("$target", final_filename)
    os.makedirs(os.path.dirname(final_path), exist_ok=True)

    if os.path.exists(local_file) and local_file != final_path:
        shutil.move(local_file, final_path)

    # Also search for the file in nested directories if not found yet
    if not os.path.exists(final_path):
        found_files = glob.glob(os.path.join(temp_dir, '**', final_filename), recursive=True)
        if found_files:
            shutil.move(found_files[0], final_path)

except Exception as e:
    print(f"⚠️ Failed to download $model/$file: {e}")
PYTHON_HF
    else
        echo "ℹ️ [DOWNLOAD] Fetching $model → $target"
        python3 - <<PYTHON_HF 2>/dev/null
import os
from huggingface_hub import snapshot_download

try:
    token = os.environ.get('HF_TOKEN')
    snapshot_download(
        repo_id="$model",
        repo_type="model",
        local_dir="$target",
        token=token,
        cache_dir=os.environ.get('HF_HUB_CACHE', '/workspace/.cache/huggingface')
    )
except Exception as e:
    print(f"⚠️ Failed to download $model: {e}")
PYTHON_HF
    fi

    sleep 1
    return 0
}

download_model_CIVITAI() {
    local url_var="$1"
    local dest_dir="$2"

    # Check if URL variable is set
    if [[ -z "${!url_var}" ]]; then
        return 0
    fi

    # Token check
    if [[ -z "$CIVITAI_TOKEN" ]]; then
        echo "⚠️ ERROR: CIVITAI_TOKEN is not set as an environment variable – '${!url_var}' not downloaded"
        return 1
    fi

    local target="/workspace/ComfyUI/models/$dest_dir"
    mkdir -p "$target"

    local url="${!url_var}"

    # Try to determine filename
    local filename
    filename="$(basename "$(printf '%s\n' "$url" | sed 's/[?#].*$//')")"

    # Fallback: unknown name (for API downloads)
    if [[ "$filename" == "download" || "$filename" == "models" || -z "$filename" ]]; then
        filename=""
    fi

    # Check if file already exists
    if [[ -n "$filename" ]] && compgen -G "$target/$filename*" > /dev/null; then
        echo "✅ [SKIP] $filename already exists in $target"
        return 0
    fi

    # Check if directory already has models
    if [[ -n "$(find "$target" -type f \( -name "*.safetensors" -o -name "*.pth" \) 2>/dev/null | head -1)" ]]; then
        echo "✅ [SKIP] Models already exist in $target - skipping CivitAI download"
        return 0
    fi

    echo "ℹ️ [DOWNLOAD] Fetching $url → $target ..."
    civitai --quit "$url" "$target" || {
        echo "⚠️ Failed to download $url"
        return 1
    }

    sleep 1
    return 0
}

download_workflow() {
    local url_var="$1"

    # Check if URL variable is set and not empty
    if [[ -z "${!url_var}" ]]; then
        return 0
    fi

    # Destination directory
    local dest_dir="/workspace/ComfyUI/user/default/workflows/"
    mkdir -p "$dest_dir"

    # Get filename from URL
    local url="${!url_var}"
    local filename
    filename=$(basename "$url")
    local filepath="${dest_dir}${filename}"

    # Skip entire process if file already exists
    if [[ -f "$filepath" ]]; then
        echo "⏭️  [SKIP] $filename already exists — skipping download and extraction"
        return 0
    fi

    # Download file
    echo "ℹ️ [DOWNLOAD] Fetching $filename ..."
    if wget -q -P "$dest_dir" "$url"; then
        echo "[DONE] Downloaded $filename"
    else
        echo "⚠️  Failed to download $url"
        return 0
    fi

    # Automatically extract common archive formats
    case "$filename" in
        *.zip)
            echo "📦  [EXTRACT] Unzipping $filename ..."
            if unzip -o "$filepath" -d "$dest_dir" >/dev/null 2>&1; then
                echo "[DONE] Extracted $filename"
            else
                echo "⚠️  Failed to unzip $filename"
            fi
            ;;
        *.tar.gz|*.tgz)
            echo "📦  [EXTRACT] Extracting $filename (tar.gz) ..."
            if tar -xzf "$filepath" -C "$dest_dir"; then
                echo "[DONE] Extracted $filename"
            else
                echo "⚠️  Failed to extract $filename"
            fi
            ;;
        *.tar.xz)
            echo "📦  [EXTRACT] Extracting $filename (tar.xz) ..."
            if tar -xJf "$filepath" -C "$dest_dir"; then
                echo "[DONE] Extracted $filename"
            else
                echo "⚠️  Failed to extract $filename"
            fi
            ;;
        *.tar.bz2)
            echo "📦  [EXTRACT] Extracting $filename (tar.bz2) ..."
            if tar -xjf "$filepath" -C "$dest_dir"; then
                echo "[DONE] Extracted $filename"
            else
                echo "⚠️  Failed to extract $filename"
            fi
            ;;
        *.7z)
            echo "📦  [EXTRACT] Extracting $filename (7z) ..."
            if 7z x -y -o"$dest_dir" "$filepath" >/dev/null 2>&1; then
                echo "[DONE] Extracted $filename"
            else
                echo "⚠️  Failed to extract $filename"
            fi
            ;;
        *)
            echo "[INFO] No extraction needed for $filename"
            ;;
    esac

    sleep 1
    return 0
}

# Provisioning if comfyUI is responding running on GPU with CUDA
if [[ "$HAS_COMFYUI" -eq 1 ]]; then
    # Pre-download FLUX.2 core models if missing
    echo "📥 Provisioning FLUX.2 core models (48GB VRAM optimized - FP8/BF16)"

    # CRITICAL: Storage Allocation on RunPod
    # ========================================
    # Root filesystem (/):       ~15GB total (VERY LIMITED - DO NOT USE FOR DOWNLOADS!)
    # Workspace (/workspace):    ~90TB+ available (USE THIS FOR ALL MODEL DOWNLOADS!)
    #
    # HuggingFace downloads default to /root/.cache/huggingface which fills up the 15GB root.
    # SOLUTION: Always set HF_HUB_CACHE=/workspace/.cache/huggingface to use workspace storage.
    # This prevents "No space left on device" errors when downloading 37GB+ of models.

    # Create model directories
    mkdir -p /workspace/ComfyUI/models/{vae,text_encoders,diffusion_models,loras}

    # Set up Hugging Face cache directory (use workspace storage, not root filesystem)
    export HF_HUB_CACHE="/workspace/.cache/huggingface"
    mkdir -p "$HF_HUB_CACHE"

    # Parallel model downloads with progress tracking
    MODELS_LOG="/tmp/model_downloads.log"
    TEMP_DOWNLOAD_DIR="/workspace/temp"
    mkdir -p "$TEMP_DOWNLOAD_DIR"
    > "$MODELS_LOG"

    # Function to download model in background using huggingface_hub with token support
    download_model_bg() {
        local model_name="$1"
        local repo_id="$2"
        local filename="$3"
        local dest_dir="$4"
        local dest_file="$5"

        (
            if [[ ! -f "$dest_file" ]]; then
                mkdir -p "$dest_dir"

                # Download using huggingface_hub Python library with token support
                # Use local_dir only (no cache_dir) so files go directly to /workspace/temp
                python3 - <<PYTHON_DOWNLOAD 2>/tmp/${model_name// /_}.log
import sys
import os
import shutil
import glob
from huggingface_hub import hf_hub_download

try:
    # Set up token if provided
    token = os.environ.get('HF_TOKEN')
    temp_dir = "$TEMP_DOWNLOAD_DIR"

    # Download using huggingface_hub library (handles authentication and resume)
    # This may create nested directories like split_files/vae/file.safetensors
    local_file = hf_hub_download(
        repo_id="$repo_id",
        filename="$filename",
        local_dir=temp_dir,
        repo_type="model",
        token=token
    )

    # Move the file to the final destination (flattening any nested paths)
    final_dest = "$dest_file"
    os.makedirs(os.path.dirname(final_dest), exist_ok=True)

    if os.path.exists(local_file) and local_file != final_dest:
        shutil.move(local_file, final_dest)
        print(f"✅ Moved to final destination: {final_dest}", file=sys.stderr)
    elif os.path.exists(final_dest):
        print(f"✅ Already at final destination: {final_dest}", file=sys.stderr)
    else:
        print(f"⚠️ File not found at {local_file} or {final_dest}", file=sys.stderr)
        sys.exit(1)

    sys.exit(0)
except Exception as e:
    print(f"⚠️ Download failed: {e}", file=sys.stderr)
    import traceback
    traceback.print_exc(file=sys.stderr)
    sys.exit(1)
PYTHON_DOWNLOAD

                if [[ $? -eq 0 ]]; then
                    echo "✅ $model_name"
                else
                    echo "⚠️ $model_name: Download failed (see /tmp/${model_name// /_}.log)"
                fi
            else
                echo "✅ $model_name (already exists)"
            fi
            echo "$model_name" >> "$MODELS_LOG"
        ) &
    }

    echo "📥 Starting parallel model downloads from Hugging Face..."

    # Validate HF_TOKEN is available for private/gated models
    if [[ -z "$HF_TOKEN" ]]; then
        echo "⚠️ HF_TOKEN not set - downloads may fail for private/gated models"
    else
        echo "✅ HF_TOKEN detected - authenticated downloads enabled"
    fi

    echo "📥 Starting parallel model downloads from Hugging Face..."

    # Start all 7 model downloads in parallel
    download_model_bg "VAE (FLUX.2 Dev)" "Comfy-Org/flux2-dev" "split_files/vae/flux2-vae.safetensors" "/workspace/ComfyUI/models/vae" "/workspace/ComfyUI/models/vae/flux2-vae.safetensors"
    download_model_bg "Text Encoder (FLUX.2 Dev FP8)" "Comfy-Org/flux2-dev" "split_files/text_encoders/mistral_3_small_flux2_fp8.safetensors" "/workspace/ComfyUI/models/text_encoders" "/workspace/ComfyUI/models/text_encoders/mistral_3_small_flux2_fp8.safetensors"
    download_model_bg "Diffusion Model (FLUX.2 Dev FP8)" "Comfy-Org/flux2-dev" "split_files/diffusion_models/flux2_dev_fp8mixed.safetensors" "/workspace/ComfyUI/models/diffusion_models" "/workspace/ComfyUI/models/diffusion_models/flux2_dev_fp8mixed.safetensors"
    download_model_bg "Turbo LoRA (FLUX.2)" "ByteZSzn/Flux.2-Turbo-ComfyUI" "Flux2TurboComfyv2.safetensors" "/workspace/ComfyUI/models/loras" "/workspace/ComfyUI/models/loras/Flux2TurboComfyv2.safetensors"
    download_model_bg "Text Encoder (FLUX.2 Klein)" "Comfy-Org/flux2-klein" "split_files/text_encoders/qwen_3_4b.safetensors" "/workspace/ComfyUI/models/text_encoders" "/workspace/ComfyUI/models/text_encoders/qwen_3_4b.safetensors"
    download_model_bg "Diffusion Model Base (FLUX.2 Klein)" "Comfy-Org/flux2-klein" "split_files/diffusion_models/flux-2-klein-base-4b.safetensors" "/workspace/ComfyUI/models/diffusion_models" "/workspace/ComfyUI/models/diffusion_models/flux-2-klein-base-4b.safetensors"
    download_model_bg "Diffusion Model Distilled (FLUX.2 Klein)" "Comfy-Org/flux2-klein" "split_files/diffusion_models/flux-2-klein-4b.safetensors" "/workspace/ComfyUI/models/diffusion_models" "/workspace/ComfyUI/models/diffusion_models/flux-2-klein-4b.safetensors"

    # Wait for all downloads and show progress every 60 seconds
    # Note: Files download to /workspace/temp first, then move to /workspace/ComfyUI/models
    TOTAL_MODELS=7
    COMPLETED=0
    LAST_REPORT=0
    while [[ $COMPLETED -lt $TOTAL_MODELS ]]; do
        COMPLETED=$(wc -l < "$MODELS_LOG" 2>/dev/null || echo 0)

        if [[ $COMPLETED -ge $TOTAL_MODELS ]]; then
            break
        fi

        NOW=$(date +%s)
        if [[ $((NOW - LAST_REPORT)) -ge 60 ]]; then
            # Check both /workspace/temp (downloading) and /workspace/ComfyUI/models (moved)
            TEMP_BYTES=$(du -sb /workspace/temp 2>/dev/null | awk '{print $1}')
            MODELS_BYTES=$(du -sb /workspace/ComfyUI/models 2>/dev/null | awk '{print $1}')
            TOTAL_BYTES=$((TEMP_BYTES + MODELS_BYTES))
            TARGET_BYTES=$((76 * 1024 * 1024 * 1024))
            PERCENT=$((TOTAL_BYTES * 100 / TARGET_BYTES))

            # Convert to human readable format
            if [[ $TOTAL_BYTES -ge $((1024 * 1024 * 1024)) ]]; then
                TOTAL_SIZE="$((TOTAL_BYTES / (1024 * 1024 * 1024)))G"
            else
                TOTAL_SIZE="$((TOTAL_BYTES / (1024 * 1024)))M"
            fi

            echo "📥 Downloaded: $TOTAL_SIZE / ~76GB ($PERCENT%)"
            LAST_REPORT=$NOW
        fi

        sleep 5
    done

    # Wait for background jobs to finish
    wait

    # Show completion status
    echo "✅ FLUX.2 models provisioning complete"
    echo "📊 Storage used for FLUX.2 models: ~50GB (VAE: 0.2GB, Text Encoder FP8: 2.8GB, Diffusion Dev: 34GB, Klein Encoder: 3.2GB, Klein Base: 8.5GB, Klein Distilled: 8.5GB, LoRA: 0.035GB)"

    # provisioning workflows
    echo "📥 Provisioning workflows"

    for i in $(seq 1 50); do
        VAR="WORKFLOW${i}"
        download_workflow "$VAR"
    done

    # Provision default workflow that auto-loads on startup
    if [[ -n "$DEFAULT_WORKFLOW_URL" ]]; then
        echo "🎯 Provisioning default auto-load workflow"
        default_wf_dir="/workspace/ComfyUI/user/default/workflows/"
        mkdir -p "$default_wf_dir"

        default_wf_filename=$(basename "$DEFAULT_WORKFLOW_URL")
        default_wf_filepath="${default_wf_dir}${default_wf_filename}"

        # Download the default workflow
        if [[ ! -f "$default_wf_filepath" ]]; then
            echo "ℹ️ [DOWNLOAD] Fetching default workflow: $default_wf_filename ..."
            if wget -q -P "$default_wf_dir" "$DEFAULT_WORKFLOW_URL"; then
                echo "✅ Downloaded default workflow: $default_wf_filename"
            else
                echo "⚠️ Failed to download default workflow from $DEFAULT_WORKFLOW_URL"
                default_wf_filename=""  # Clear filename if download failed
            fi
        else
            echo "⏭️ [SKIP] Default workflow already exists"
        fi

        # Configure ComfyUI to auto-load this workflow
        if [[ -n "$default_wf_filename" && -f "$default_wf_filepath" ]]; then
            default_wf_settings_file="/workspace/ComfyUI/user/default/comfy.settings.json"

            # Update comfy.settings.json to set the default workflow
            python3 - <<PYTHON
import json
import os

settings_file = "${default_wf_settings_file}"
workflow_name = "${default_wf_filename}"

# Read existing settings
try:
    with open(settings_file, 'r') as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

# Set the default workflow to auto-load
settings["Comfy.PreviousWorkflow"] = workflow_name

# Write back to settings file
os.makedirs(os.path.dirname(settings_file), exist_ok=True)
with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=4)

print(f"✅ Configured ComfyUI to auto-load: {workflow_name}")
PYTHON
        fi
    else
        echo "ℹ️ No DEFAULT_WORKFLOW_URL set, using built-in workflows"
    fi

    # provisioning Models and loras (custom models via env vars)
    echo "📥 Provisioning custom models via environment variables"
	
    # categorie:  NAME:SUFFIX:MAP
    CATEGORIES_HF=(
      "VAE:VAE_FILENAME:vae"
      "UPSCALER:UPSCALER_PTH:upscale_models"
      "LORA:LORA_FILENAME:loras"
      "TEXT_ENCODERS:TEXT_ENCODERS_FILENAME:text_encoders"
      "CLIP_VISION:CLIP_VISION_FILENAME:clip_vision"
      "PATCHES:PATCHES_FILENAME:model_patches"
      "AUDIO_ENCODERS:AUDIO_ENCODERS_FILENAME:audio_encoders"
      "DIFFUSION_MODELS:DIFFUSION_MODELS_FILENAME:diffusion_models"
      "CHECKPOINTS:CHECKPOINTS_FILENAME:checkpoints"
      "VL:VL_FILENAME:VLM"
      "SAMS:SAMS_FILENAME:sams"
      "LATENT_UPSCALE:LATENT_UPSCALE_FILENAME:latent_upscale_models"
    )
	
    for cat in "${CATEGORIES_HF[@]}"; do
      IFS=":" read -r NAME SUFFIX DIR <<< "$cat"
	
      for i in $(seq 1 20); do
        VAR1="HF_MODEL_${NAME}${i}"
        VAR2="HF_MODEL_${SUFFIX}${i}"
        download_model_HF "$VAR1" "$VAR2" "$DIR"
      done
    done
	
    # Huggingface download file to specified directory
    for i in $(seq 1 20); do
        VAR1="HF_MODEL${i}"
        VAR2="HF_MODEL_FILENAME${i}"
        DIR_VAR="HF_MODEL_DIR${i}"
        download_generic_HF "${VAR1}" "${VAR2}" "${!DIR_VAR}"
    done
	
    # Huggingface download full model to specified directory
    for i in $(seq 1 20); do
        VAR1="HF_FULL_MODEL${i}"
        DIR_VAR="HF_MODEL_DIR${i}"
        download_generic_HF "${VAR1}" "" "${!DIR_VAR}"
    done  
	 
    # provisioning Models and loras CIVITAI
    echo "📥 Provisioning models CIVITAI"
	
    # categorie: NAME:MAP	
    CATEGORIES_CIVITAI=(
       "LORA_URL:loras"
	   "UNET_URL:diffusion_models"
    )

    for cat in "${CATEGORIES_CIVITAI[@]}"; do
      IFS=":" read -r NAME DIR <<< "$cat"
	
      for i in $(seq 1 50); do
        VAR1="CIVITAI_MODEL_${NAME}${i}"
        download_model_CIVITAI "$VAR1" "$DIR"
      done
    done
	
    HAS_PROVISIONING=1
else
    HAS_PROVISIONING=0   
    echo "⚠️ Skipped Provisioning: No workflows or models downloaded as ComfyUI is not online"
fi

# Environment
echo "ℹ️ Running environment"

python - <<'PY'
import platform

# Safe imports – don't explode if something is missing
try:
    import torch
except Exception as e:
    print(f"PyTorch import error: {e}")
    torch = None

try:
    import triton
except Exception:
    triton = None

try:
    import onnxruntime as ort
except Exception:
    ort = None

print(f"Python: {platform.python_version()}")

if torch is not None:
    print(f"PyTorch: {torch.__version__}")
    print(f"CUDA available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"  ↳ CUDA runtime: {torch.version.cuda}")
        print(f"  ↳ GPU(s): {[torch.cuda.get_device_name(i) for i in range(torch.cuda.device_count())]}")
        try:
            import torch.backends.cudnn as cudnn
            print(f"  ↳ cuDNN: {cudnn.version()}")
        except Exception:
            pass
    print("Torch build info:")
    try:
        torch.__config__.show()
    except Exception:
        pass
else:
    print("PyTorch: not available")

if triton is not None:
    print(f"Triton version: {triton.__version__}")
else:
    print("Triton: not available")

if ort is not None:
    print(f"ONNX Runtime version: {ort.__version__}")
    providers = ort.get_available_providers()
    print(f"Available providers: {providers}")
    print(f"CUDA provider available: {'CUDAExecutionProvider' in providers}")
else:
    print("ONNX Runtime: not available")
PY

python - <<'PY'
import llama_cpp
print("llama-cpp-python version:", llama_cpp.__version__)
try:
    from llama_cpp import llama_print_system_info
    info = llama_print_system_info()
    print(info.decode('utf-8'))
except Exception as e2:
    print("Failed:", e2)
PY

if [[ "$HAS_PROVISIONING" -eq 1 ]]; then 
    echo "🎉 Provisioning done, ready to create AI content 🎉"
		
	if [[ "$HAS_GPU_RUNPOD" -eq 1 ]]; then
	  echo "ℹ️ Connect to the following services from console menu or url"
	
	  if [[ -z "${RUNPOD_POD_ID:-}" ]]; then
	    echo "⚠️ RUNPOD_POD_ID not set — service URLs unavailable"
	  else
	    declare -A SERVICES=(
	      ["Code-Server"]=9000
	      ["ComfyUI"]=8188
	    )
	
	    # Local health checks (inside the pod)
	    for service in "${!SERVICES[@]}"; do
	      port="${SERVICES[$service]}"
	      url="https://${RUNPOD_POD_ID}-${port}.proxy.runpod.net/"
	      local_url="http://127.0.0.1:${port}/"
	
	      echo "👉 🔗 Service ${service} : ${url}"
	
	      # Check service locally (no proxy dependency)
	      http_code="$(curl -sS -o /dev/null -m 2 --connect-timeout 1 -w "%{http_code}" "$local_url" || true)"
	
	      # Treat common “service is up but protected/redirect” codes as UP
	      if [[ "$http_code" =~ ^(200|301|302|401|403|404)$ ]]; then
	        echo "✅ ${service} is running (local ${local_url}, HTTP ${http_code})"
	      else
	        echo "❌ ${service} not responding yet (local ${local_url}, HTTP ${http_code})"
	      fi
	    done
		
		echo "👉 🔗 Lora-Manager: https://${RUNPOD_POD_ID}-8188.proxy.runpod.net/loras"
	  fi
	fi
	
    if [[ -n "$PASSWORD" ]]; then
		echo "ℹ️ Code-Server login use PASSWORD set as env"
	else 
		echo "⚠️ Code-Server login use the logged password"
		cat /root/.config/code-server/config.yaml        
    fi	
else
    echo "ℹ️ Running error diagnosis"

    if [[ "$HAS_GPU_RUNPOD" -eq 0 ]]; then
        echo "⚠️ Pod started without a runpod GPU"
    fi

    if [[ "$HAS_CUDA" -eq 0 ]]; then
        echo "❌ Pytorch CUDA driver error/mismatch/not available"
        if [[ "$HAS_GPU_RUNPOD" -eq 1 ]]; then
            echo "⚠️ [SOLUTION] Deploy pod on another region then RUNPOD_DC_ID  ⚠️"
        fi
    fi

    if [[ "$HAS_CUDA" -eq 1 && "$HAS_COMFYUI" -eq 0 ]]; then
        echo "❌ ComfyUI is not online"
        echo "⚠️ [SOLUTION] restart pod ⚠️"
    fi
fi

# Keep the container running
echo "ℹ️ End script"
exec sleep infinity


