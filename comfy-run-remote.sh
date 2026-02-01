#!/bin/bash
################################################################################
# ComfyUI Remote Workflow Runner - Execute on RunPod from Localhost
################################################################################
#
# DESCRIPTION:
#   Remote execution script for submitting ComfyUI workflows to RunPod instances
#   from localhost. Handles workflow submission, progress monitoring, and image
#   download - all from the local machine via RunPod proxy URLs.
#
# LOCATION:
#   ./rundpod-flux2-dev-turbo/workflows/comfy-run-remote.sh
#
# FEATURES:
#   ✓ Remote pod connection via RunPod proxy URLs
#   ✓ Parameter substitution (${PROMPT}, ${SEED}, ${IMAGE_ID}, ${OUTPUT_FOLDER})
#   ✓ ComfyUI REST API integration with polling
#   ✓ Automatic image download to localhost
#   ✓ Comprehensive generation logging
#   ✓ Network retry with exponential backoff
#   ✓ Pod connectivity validation
#   ✓ Error handling and recovery
#
# REQUIREMENTS:
#   - RunPod pod running ComfyUI (accessible via proxy URL)
#   - curl, jq, python3 (installed on localhost)
#   - RunPod pod URL or RUNPOD_POD_URL environment variable
#
# ENVIRONMENT VARIABLES:
#   RUNPOD_POD_URL   Pod proxy URL (e.g., https://{POD_ID}-8188.proxy.runpod.net)
#   GENERATION_LOG_DIR (default: ./logs/generations/)
#
# RETURN CODES:
#   0 - Success: Workflow completed and images downloaded
#   1 - Failure: Validation error, connection failure, or execution failure
#   2 - Timeout: Workflow exceeded timeout waiting period
#
# VERSION: 1.0.0
# CREATED: 2026-02-01
#
################################################################################

set -euo pipefail

################################################################################
# HELP & USAGE
################################################################################

show_help() {
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════════╗
║            ComfyUI Remote Workflow Runner - Help & Usage                   ║
╚════════════════════════════════════════════════════════════════════════════╝

USAGE:
    ./comfy-run-remote.sh --prompt "Your prompt" [OPTIONS]

REQUIRED ARGUMENTS:
    --prompt TEXT              The prompt text to pass to the workflow
                              Example: --prompt "A beautiful sunset over mountains"

OPTIONAL POD CONFIGURATION:
    --pod-url URL              RunPod proxy URL for ComfyUI instance (auto-detected if not provided)
                              Format: https://{POD_ID}-8188.proxy.runpod.net
                              Example: --pod-url https://zu9sxe2gu0lswm-8188.proxy.runpod.net
                              OR set via RUNPOD_POD_URL environment variable
                              OR auto-detected from runpodctl

OPTIONS:
    --workflow FILE            Workflow JSON file (default: flux2_turbo_512x512_parametric_api.json)
                              Supports both ComfyUI UI format and API format
                              Example: --workflow flux2_turbo_512x512_api.json

    --image-id ID             Unique identifier for this generation
                              Example: --image-id "batch_001_001"

    --output-folder PATH      Remote output folder on pod (default: /workspace/output/)
                              Example: --output-folder "/workspace/custom_output/"

    --local-output PATH       Local directory for downloaded images (default: ./output/)
                              Example: --local-output /tmp/comfy_outputs/

    --seed SEED               Seed value for reproducibility (default: auto-generated)
                              Example: --seed 12345

    --timeout SECONDS         Max execution time in seconds (default: 3600)
                              Example: --timeout 1800

    --download / --no-download Enable/disable image download (default: --download)
                              Example: --no-download (skip downloading images)

    --steps NUM               Number of inference steps (default: 4)
                              Example: --steps 20

    --width NUM               Image width in pixels (default: 512)
                              Example: --width 768

    --height NUM              Image height in pixels (default: 512)
                              Example: --height 768

    --batch-size NUM          Number of images per batch (default: 1)
                              Example: --batch-size 4

    --help, -h               Display this help message and exit

EXAMPLES:
    # Basic remote execution with auto-detection and auto-download to ./output/
    ./comfy-run-remote.sh --prompt "A red car"

    # Full specification with explicit pod URL
    ./comfy-run-remote.sh --prompt "A red car" \
                          --pod-url https://zu9sxe2gu0lswm-8188.proxy.runpod.net \
                          --image-id "test_001" \
                          --seed 42 \
                          --local-output ./remote_outputs/

    # Using environment variable for pod URL (overrides auto-detection)
    export RUNPOD_POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"
    ./comfy-run-remote.sh --prompt "A test image" --image-id "test_001"

    # Submit workflow without downloading images
    ./comfy-run-remote.sh --prompt "A test" --no-download

ENVIRONMENT CONFIGURATION:
    RUNPOD_POD_URL           Pod proxy URL (optional, auto-detected if not set)
    GENERATION_LOG_DIR       Logging directory (default: ./logs/generations/)

    Example (auto-detection):
    ./comfy-run-remote.sh --prompt "Test"

    Example (with explicit pod URL):
    export RUNPOD_POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"
    ./comfy-run-remote.sh --prompt "Test"

OUTPUT FILES:
    • Generated images:  {LOCAL_OUTPUT}/{IMAGE_ID}_{HH}{MM}{SS}_*.png
    • Generation log:    {LOG_DIR}/generation_{TIMESTAMP}.log

LOGGING:
    All remote generations are logged to:
    {GENERATION_LOG_DIR}/generation_{TIMESTAMP}.log

    Log includes:
    - Input parameters and pod connection details
    - Pod connectivity checks and API responses
    - Workflow submission and polling details
    - Image download progress
    - Final output status and file locations

RETURN VALUES:
    0  = Success: Workflow completed and images downloaded
    1  = Error: Connection failure, validation error, or API error
    2  = Timeout: Workflow exceeded execution timeout

COMMON ISSUES:

    1. "Pod unreachable"
       → Check pod is running: runpodctl get pod
       → Auto-detection will fail if no pod is RUNNING
       → Ensure pod ID format is correct in RUNPOD_POD_URL if set manually

    2. "Pod URL format invalid"
       → Ensure format: https://{POD_ID}-8188.proxy.runpod.net
       → Remove trailing slashes if present

    3. "Connection timeout"
       → Check your network connection
       → Increase --timeout if pod is busy: --timeout 7200

WORKFLOW COMPATIBILITY:
    • Workflows must match the local comfy-run.sh format
    • Supports both UI and API format workflows (auto-converted)
    • Custom workflows can be specified with --workflow

POD ID INFORMATION:
    ⚠️  Pod ID changes when pod is restarted
    Get current pod ID:  runpodctl pod list
    Pod ID format:       {POD_ID}-8188.proxy.runpod.net

PERFORMANCE NOTES:
    - Workflow submission: ~100-200ms
    - Polling interval: 2 seconds
    - Model loading on pod: 5-20s (first time), <100ms (cached)
    - Image download: depends on image size and network
    - Typical total time: 10-60 seconds (including model load)

ADVANCED USAGE:

    Batch processing:
    ─────────────────
    export RUNPOD_POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"
    for i in {1..10}; do
        ./comfy-run-remote.sh --prompt "Image $i" --image-id "batch_$(printf '%03d' $i)"
    done

    Parallel execution (caution with pod resource limits):
    ─────────────────────────────────────────────────────
    RUNPOD_POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"
    ./comfy-run-remote.sh --prompt "Job 1" --image-id "job_001" &
    ./comfy-run-remote.sh --prompt "Job 2" --image-id "job_002" &
    ./comfy-run-remote.sh --prompt "Job 3" --image-id "job_003" &
    wait

SUPPORT:
    For pod management issues:
    - RunPod Dashboard: https://www.runpod.io/
    - runpodctl documentation: runpodctl --help

    For ComfyUI issues:
    - ComfyUI Docs: https://docs.comfy.org
    - GitHub Issues: https://github.com/Comfy-Org/ComfyUI/issues

EOF
}

################################################################################
# UTILITY & LOGGING FUNCTIONS
################################################################################

# Print info message to stdout
log_info() {
    echo "[INFO] $*"
}

# Print success message to stdout
log_success() {
    echo "[✓] $*"
}

# Print warning message to stdout
log_warn() {
    echo "[⚠] $*"
}

# Print error message to stderr
log_error() {
    echo "[✗] $*" >&2
}

# Print debug message to stderr (only if DEBUG=1)
log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

################################################################################
# GENERATION LOGGING FUNCTIONS
################################################################################

# Initialize generation log file with header and parameters
init_generation_log() {
    mkdir -p "$GENERATION_LOG_DIR" || return 1

    LOG_FILE="${GENERATION_LOG_DIR}generation_${START_TIMESTAMP}.log"

    cat > "$LOG_FILE" << EOF
████████████████████████████████████████████████████████████████████████████████
 REMOTE GENERATION LOG - ${START_TIME}
████████████████████████████████████████████████████████████████████████████████

GENERATION METADATA:
  Timestamp:        ${START_TIME}
  Client ID:        ${CLIENT_ID}
  Log File:         ${LOG_FILE}
  Execution Mode:   REMOTE (via RunPod proxy)

POD CONNECTION:
  Pod URL:          ${POD_URL}
  Timeout:          ${TIMEOUT_SECONDS}s

INPUT PARAMETERS:
  Prompt:           ${PROMPT}
  Image ID:         ${IMAGE_ID}
  Seed:             ${SEED}
  Steps:            ${STEPS}
  Width:            ${WIDTH}
  Height:           ${HEIGHT}
  Batch Size:       ${BATCH_SIZE}
  Workflow:         ${WORKFLOW_FILE}
  Output Folder:    ${OUTPUT_FOLDER}
  Local Output:     ${LOCAL_OUTPUT_FOLDER}
  Download Images:  ${DOWNLOAD_IMAGES}
  Filename Prefix:  ${FILENAME_PREFIX}

EXECUTION LOG:
─────────────────────────────────────────────────────────────────────────────
EOF
}

# Log message to file with timestamp
log_to_file() {
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"
    fi
}

# Finalize generation log with results and completion status
finalize_generation_log() {
    if [[ -n "${LOG_FILE:-}" ]]; then
        local END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
        local STATUS="$1"
        local OUTPUT_DETAILS="${2:-  (No output captured)}"

        cat >> "$LOG_FILE" << EOF
─────────────────────────────────────────────────────────────────────────────

COMPLETION STATUS:
  Status:           ${STATUS}
  Prompt ID:        ${PROMPT_ID}
  Start Time:       ${START_TIME}
  End Time:         ${END_TIME}
  Local Output:     ${LOCAL_OUTPUT_FOLDER}

DOWNLOADED OUTPUTS:
${OUTPUT_DETAILS}

████████████████████████████████████████████████████████████████████████████████
EOF
        log_info "Generation log: $LOG_FILE"
    fi
}

################################################################################
# CONFIGURATION & INITIALIZATION
################################################################################

# Get script directory (where workflow files are located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default configuration values
WORKFLOW_FILE="${SCRIPT_DIR}/workflows/flux2_turbo_512x512_parametric_api.json"
PROMPT=""
IMAGE_ID="UNDEFINED_ID_"
OUTPUT_FOLDER="/workspace/output/"
LOCAL_OUTPUT_FOLDER="./output/"
SEED=""
POD_URL=""
DOWNLOAD_IMAGES="true"
TIMEOUT_SECONDS=3600
GENERATION_LOG_DIR="${GENERATION_LOG_DIR:-./logs/generations/}"
RECOVERY_DIR="${RECOVERY_DIR:-./logs/recovery/}"
PROMPT_ID=""
LOG_FILE=""
RECOVERY_FILE=""

# Workflow parameters (optional, with defaults)
STEPS=4
WIDTH=512
HEIGHT=512
BATCH_SIZE=1

# Timestamp and identification
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
START_TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
CLIENT_ID="claude-code-remote-${START_TIMESTAMP}-$(date +%N)"

################################################################################
# ARGUMENT PARSING & VALIDATION
################################################################################

# Parse command-line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --workflow)
                WORKFLOW_FILE="$2"
                shift 2
                ;;
            --prompt)
                PROMPT="$2"
                shift 2
                ;;
            --image-id)
                IMAGE_ID="$2"
                shift 2
                ;;
            --output-folder)
                OUTPUT_FOLDER="$2"
                shift 2
                ;;
            --local-output)
                LOCAL_OUTPUT_FOLDER="$2"
                # Ensure trailing slash
                [[ "$LOCAL_OUTPUT_FOLDER" != */ ]] && LOCAL_OUTPUT_FOLDER="${LOCAL_OUTPUT_FOLDER}/"
                shift 2
                ;;
            --pod-url)
                POD_URL="$2"
                shift 2
                ;;
            --seed)
                SEED="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT_SECONDS="$2"
                shift 2
                ;;
            --download)
                DOWNLOAD_IMAGES="true"
                shift 1
                ;;
            --no-download)
                DOWNLOAD_IMAGES="false"
                shift 1
                ;;
            --steps)
                STEPS="$2"
                shift 2
                ;;
            --width)
                WIDTH="$2"
                shift 2
                ;;
            --height)
                HEIGHT="$2"
                shift 2
                ;;
            --batch-size)
                BATCH_SIZE="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo ""
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Validate required arguments and parameters
validate_arguments() {
    # Prompt is required
    if [[ -z "$PROMPT" ]]; then
        log_error "Prompt is required (--prompt)"
        echo ""
        echo "Use --help for usage information"
        exit 1
    fi


    # Workflow file must exist
    if [[ ! -f "$WORKFLOW_FILE" ]]; then
        log_error "Workflow file not found: $WORKFLOW_FILE"
        exit 1
    fi
}

# Generate or use provided seed
generate_seed() {
    if [[ -z "$SEED" ]]; then
        local EPOCH_TIME=$(date +%s)
        local RANDOM_INT=$((RANDOM * 32768 + RANDOM))
        SEED=$((RANDOM_INT + EPOCH_TIME))
        log_debug "Auto-generated seed: $SEED"
    fi
}

# Compute derived values from parameters
compute_derived_values() {
    # Append IMAGE_ID to prompt to prevent caching
    if [[ -n "$IMAGE_ID" && "$IMAGE_ID" != "UNDEFINED_ID_" ]]; then
        PROMPT="${PROMPT} (id: ${IMAGE_ID})"
    fi

    # Compute filename prefix from IMAGE_ID + HH:MM:SS
    local HOUR=$(date '+%H')
    local MINUTE=$(date '+%M')
    local SECOND=$(date '+%S')
    FILENAME_PREFIX="${IMAGE_ID}_${HOUR}${MINUTE}${SECOND}"
}

# Export variables for use in envsubst and subprocesses
export_variables() {
    export PROMPT
    export IMAGE_ID
    export OUTPUT_FOLDER
    export SEED
    export FILENAME_PREFIX
    export STEPS
    export WIDTH
    export HEIGHT
    export BATCH_SIZE
}

# Print startup information
print_startup_info() {
    echo ""
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "ComfyUI Remote Workflow Execution"
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "Timestamp:        ${START_TIME}"
    log_info "Pod URL:          ${POD_URL}"
    log_info "Client ID:        ${CLIENT_ID}"
    log_info "Timeout:          ${TIMEOUT_SECONDS}s"
    log_info ""
    log_info "Configuration:"
    log_info "  Workflow:       $(basename "$WORKFLOW_FILE")"
    log_info "  Prompt:         ${PROMPT:0:60}$( (( ${#PROMPT} > 60 )) && echo "..." || echo "" )"
    log_info "  Image ID:       ${IMAGE_ID}"
    log_info "  Seed:           ${SEED}"
    log_info "  Steps:          ${STEPS}"
    log_info "  Size:           ${WIDTH}x${HEIGHT}"
    log_info "  Batch Size:     ${BATCH_SIZE}"
    log_info "  Local Output:   ${LOCAL_OUTPUT_FOLDER}"
    log_info "  Download:       ${DOWNLOAD_IMAGES}"
    log_info ""
}

################################################################################
# MAIN INITIALIZATION SEQUENCE (RUN EARLY)
################################################################################

# Parse arguments
parse_arguments "$@"

# Detect pod URL with priority: argument → env var → runpodctl → error
detect_pod_url_from_runpodctl() {
    # Try to get pod ID from runpodctl
    if ! command -v runpodctl &> /dev/null; then
        return 1
    fi

    local pod_id=$(runpodctl get pod 2>/dev/null | grep "RUNNING" | head -1 | awk '{print $1}')
    if [[ -n "$pod_id" ]]; then
        echo "https://${pod_id}-8188.proxy.runpod.net"
        return 0
    fi

    return 1
}

if [[ -z "$POD_URL" ]]; then
    # Priority 2: Check environment variable
    if [[ -n "${RUNPOD_POD_URL:-}" ]]; then
        POD_URL="${RUNPOD_POD_URL}"
    # Priority 3: Auto-detect using runpodctl
    elif POD_URL=$(detect_pod_url_from_runpodctl); then
        log_debug "Auto-detected pod URL from runpodctl: $POD_URL"
    fi
fi

# Validate arguments
validate_arguments

# Generate/validate seed
generate_seed

# Compute derived values
compute_derived_values

# Export variables
export_variables

# Initialize logging
init_generation_log
log_to_file "Remote generation started with parameters"

# Print startup info
print_startup_info

################################################################################
# DEPENDENCY CHECKS
################################################################################

# Check for required command in PATH
check_command() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

# Verify all required dependencies are available
verify_dependencies() {
    log_info "Verifying dependencies..."

    # curl is required
    if ! check_command curl; then
        log_error "curl not found - cannot proceed"
        log_to_file "ERROR: curl command not found"
        exit 1
    fi
    log_debug "✓ curl found"

    # jq is required
    if ! check_command jq; then
        log_error "jq not found - cannot proceed"
        log_to_file "ERROR: jq command not found"
        exit 1
    fi
    log_debug "✓ jq found"

    # python3 is required
    if ! check_command python3; then
        log_error "python3 not found - cannot proceed"
        log_to_file "ERROR: python3 command not found"
        exit 1
    fi
    log_debug "✓ python3 found"

    log_success "All dependencies verified"
    log_to_file "Dependencies verified: curl, jq, python3"
}

################################################################################
# RECOVERY & PERSISTENCE FUNCTIONS
################################################################################

# Save prompt_id for recovery after timeout
save_prompt_for_recovery() {
    local prompt_id="$1"
    local pod_url="$2"

    mkdir -p "$RECOVERY_DIR" || return 1

    RECOVERY_FILE="${RECOVERY_DIR}/prompt_${START_TIMESTAMP}.recovery"

    cat > "$RECOVERY_FILE" << EOF
# Workflow Recovery File
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Use this file to check the status of a timed-out workflow

PROMPT_ID=$prompt_id
POD_URL=$pod_url
IMAGE_ID=$IMAGE_ID
SEED=$SEED
LOCAL_OUTPUT_FOLDER=$LOCAL_OUTPUT_FOLDER

# To check the status of this workflow, run:
# curl -s "\${POD_URL}/history/\${PROMPT_ID}" | jq .

# To download images if they're ready, run:
# curl -s "\${POD_URL}/history/\${PROMPT_ID}" | jq ".[\"\${PROMPT_ID}\"].outputs"
EOF

    log_info "Recovery file saved: $RECOVERY_FILE"
    log_to_file "Recovery file saved: $RECOVERY_FILE"
    return 0
}

# Display recovery instructions
show_recovery_instructions() {
    local prompt_id="$1"
    local pod_url="$2"
    local recovery_file="$3"

    log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_error "WORKFLOW TIMEOUT - RECOVERY INFORMATION"
    log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_error ""
    log_error "The workflow timed out but may still be processing on the pod."
    log_error ""
    log_error "Prompt ID: $prompt_id"
    log_error "Pod URL: $pod_url"
    log_error ""
    log_error "To check status, run:"
    log_error "  curl -s '$pod_url/history/$prompt_id' | jq ."
    log_error ""
    log_error "Recovery file: $recovery_file"
    log_error ""
    log_error "To continue checking, you can:"
    log_error "  • Wait for pod to finish: curl -s '$pod_url/history/$prompt_id' | jq .\"$prompt_id\".outputs"
    log_error "  • Check a different timeout: ./comfy-run-remote.sh --prompt \"...\" --timeout 7200"
    log_error ""
    log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

################################################################################
# CONNECTION MANAGEMENT FUNCTIONS
################################################################################

# Normalize pod URL to standard format
# Accepts: https://pod-id-8188.proxy.runpod.net, pod-id-8188.proxy.runpod.net, with/without trailing /
normalize_pod_url() {
    local url="$1"

    # Remove trailing slash
    url="${url%/}"

    # Add https:// if not present
    if [[ ! "$url" =~ ^https?:// ]]; then
        url="https://${url}"
    fi

    echo "$url"
}

# Check remote pod connectivity
check_remote_connectivity() {
    log_info "Checking pod connectivity..."
    log_to_file "Checking pod connectivity to: ${POD_URL}"

    # Test /system_stats endpoint
    local response
    response=$(curl -s -w "\n%{http_code}" \
        --connect-timeout 5 \
        --max-time 10 \
        "${POD_URL}/system_stats" 2>/dev/null || echo "")

    if [[ -z "$response" ]]; then
        log_error "No response from pod (network error)"
        log_to_file "ERROR: No response from pod at ${POD_URL}"
        return 1
    fi

    local http_code=$(echo "$response" | tail -n 1)
    local body=$(echo "$response" | head -n -1)

    if [[ "$http_code" == "200" ]]; then
        log_success "Pod is accessible (HTTP 200)"
        log_to_file "Pod connectivity check successful: HTTP 200"
        log_debug "Pod response: ${body:0:100}"
        return 0
    else
        log_error "Pod returned HTTP ${http_code}"
        log_to_file "ERROR: Pod connectivity check failed: HTTP ${http_code}"
        return 1
    fi
}

# Retry operation with exponential backoff
retry_with_backoff() {
    local max_attempts=5
    local timeout=1
    local attempt=1

    while (( attempt <= max_attempts )); do
        log_debug "Attempt $attempt/$max_attempts"
        if "$@"; then
            return 0
        fi

        if (( attempt < max_attempts )); then
            log_warn "Attempt $attempt failed, retrying in ${timeout}s..."
            sleep "$timeout"
            timeout=$((timeout * 2))
        fi

        ((attempt++))
    done

    log_error "Operation failed after $max_attempts attempts"
    return 1
}

################################################################################
# WORKFLOW PROCESSING FUNCTIONS (REUSED FROM comfy-run.sh)
################################################################################

# These functions are reused from comfy-run.sh with minimal modifications
# They process workflows locally before sending to remote pod

# Check if workflow is in UI format (has "nodes" array at top level)
# Returns 0 (true) if UI format, 1 (false) otherwise
is_ui_format() {
    jq -e '.nodes? | type == "array"' "$1" > /dev/null 2>&1
}

# Process workflow template with variable substitution
process_workflow_template() {
    local workflow_file="$1"

    log_debug "Processing workflow template..."
    log_to_file "Processing workflow: $(basename "$workflow_file")"

    # Use envsubst to substitute variables in the workflow file
    # This allows for ${PROMPT}, ${SEED}, ${WIDTH}, ${HEIGHT}, etc. substitution
    # Note: We skip JSON validation before substitution because the template
    # may contain unquoted variable references like: "width": ${WIDTH}
    # which are invalid JSON syntax but become valid after substitution
    (envsubst < "$workflow_file") 2>/dev/null || cat "$workflow_file"
}

# Convert UI format to API format using Python
# Input: JSON workflow as string (argument)
# Output: Converted workflow to stdout
convert_ui_to_api_format() {
    local workflow_json="$1"
    local temp_workflow=$(mktemp)

    log_debug "Converting workflow to API format..."
    log_to_file "Converting workflow from UI to API format"

    # Write workflow to temp file
    echo "$workflow_json" > "$temp_workflow"

    python3 << PYTHON_EOF
import json
import sys

try:
    with open("$temp_workflow", 'r') as f:
        workflow = json.load(f)

    # Check if already in API format (has numbered keys with class_type)
    is_api_format = any(
        isinstance(v, dict) and 'class_type' in v
        for k, v in workflow.items()
        if k.isdigit() or isinstance(k, int)
    )

    if is_api_format:
        # Already in API format
        json.dump(workflow, sys.stdout)
        sys.exit(0)

    # Check if it's UI format (has 'nodes' array)
    if 'nodes' in workflow and isinstance(workflow.get('nodes'), list):
        # Build link mapping
        link_map = {}
        if 'links' in workflow and workflow['links']:
            for link in workflow['links']:
                if len(link) >= 6:
                    link_id, src_node, src_slot, tgt_node, tgt_slot = link[:5]
                    link_map[link_id] = [str(src_node), src_slot]

        # Convert UI to API format
        api_workflow = {}
        ui_only_types = {'Note', 'Reroute', 'PrimitiveNode'}

        for node in workflow['nodes']:
            node_id = str(node.get('id', ''))
            node_type = node.get('type', '')

            if not node_id or node_type in ui_only_types:
                continue

            api_node = {
                'class_type': node_type,
                'inputs': {}
            }

            # Process widget values (parameters)
            if 'widgets_values' in node:
                widget_values = node['widgets_values']
                if isinstance(widget_values, list):
                    # Get input names from node (if available in UI)
                    input_names = []
                    if 'inputs' in node and isinstance(node['inputs'], list):
                        for inp in node['inputs']:
                            if 'name' in inp:
                                input_names.append(inp['name'])

                    # Assign widget values to inputs
                    if input_names:
                        for idx, val in enumerate(widget_values):
                            if idx < len(input_names):
                                api_node['inputs'][input_names[idx]] = val
                    else:
                        # Fallback: generic naming
                        for idx, val in enumerate(widget_values):
                            api_node['inputs'][f'param_{idx}'] = val

            api_workflow[node_id] = api_node

        json.dump(api_workflow, sys.stdout)
    else:
        # Unknown format, return as-is
        json.dump(workflow, sys.stdout)

except Exception as e:
    print(f'{{"error": "Conversion failed: {str(e)}"}}', file=sys.stderr)
    sys.exit(1)
PYTHON_EOF

    # Clean up temp file
    rm -f "$temp_workflow"
}

# Validate workflow structure (works with multiple formats)
validate_workflow_structure() {
    local workflow="$1"

    log_debug "Validating workflow structure..."

    # Check if it's valid JSON
    if ! echo "$workflow" | jq empty 2>/dev/null; then
        log_error "Workflow is not valid JSON"
        return 1
    fi

    # Check for valid workflow formats
    local is_valid=false

    # Format 1: UI format (has 'nodes' array)
    if echo "$workflow" | jq -e '.nodes? | type == "array"' > /dev/null 2>&1; then
        is_valid=true
    fi

    # Format 2: API format with 'prompt' key (ComfyUI standard)
    if echo "$workflow" | jq -e '.prompt? | type == "object"' > /dev/null 2>&1; then
        is_valid=true
    fi

    # Format 3: API format with numbered string keys ("1", "2", etc.)
    if echo "$workflow" | jq -e 'to_entries | map(select((.key | test("^[0-9]+$")) and (.value | type == "object" and has("class_type")))) | length > 0' > /dev/null 2>&1; then
        is_valid=true
    fi

    if [[ "$is_valid" == "false" ]]; then
        log_error "Workflow format not recognized"
        return 1
    fi

    log_success "Workflow structure is valid"
    return 0
}

# Substitute seed in KSampler nodes
# Handles both API formats (prompt wrapper and direct object)
substitute_seed() {
    local workflow="$1"
    local seed="$2"

    log_debug "Substituting seed: $seed"

    # Check if workflow has "prompt" wrapper
    if echo "$workflow" | jq -e '.prompt?' > /dev/null 2>&1; then
        # Format: {"prompt": {"1": {...}, "2": {...}}}
        echo "$workflow" | jq "
            .prompt |= (
                to_entries |
                map(
                    if .value.class_type == \"KSampler\" then
                        .value.inputs.seed = $seed
                    else
                        .
                    end
                ) |
                from_entries
            )
        "
    else
        # Format: {"1": {...}, "2": {...}} direct
        echo "$workflow" | jq "
            to_entries |
            map(
                if .value.class_type == \"KSampler\" then
                    .value.inputs.seed = $seed
                else
                    .
                end
            ) |
            from_entries
        "
    fi
}

################################################################################
# REMOTE EXECUTION FUNCTIONS
################################################################################

# Submit workflow to remote pod
submit_remote_workflow() {
    local workflow_json="$1"

    log_info "Submitting workflow to remote pod..."
    log_to_file "Submitting workflow to pod at ${POD_URL}"

    # Extract the actual workflow prompt object
    # Handle both formats: {"prompt": {...}} and direct {...}
    local prompt_obj
    if echo "$workflow_json" | jq -e '.prompt?' > /dev/null 2>&1; then
        # Extract the prompt object from wrapper
        prompt_obj=$(echo "$workflow_json" | jq '.prompt')
    else
        # Already in the correct format
        prompt_obj="$workflow_json"
    fi

    # Prepare request body
    local request_body=$(jq -n \
        --arg prompt_id "$CLIENT_ID" \
        --argjson workflow "$prompt_obj" \
        '{
            prompt: $workflow,
            client_id: $prompt_id
        }')

    log_debug "Request body (first 200 chars): ${request_body:0:200}"

    # Submit to pod
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H 'Content-Type: application/json' \
        --connect-timeout 5 \
        --max-time 30 \
        -d "$request_body" \
        "${POD_URL}/prompt" 2>/dev/null || echo "")

    if [[ -z "$response" ]]; then
        log_error "No response from pod (network error)"
        log_to_file "ERROR: No response from pod during workflow submission"
        return 1
    fi

    local http_code=$(echo "$response" | tail -n 1)
    local body=$(echo "$response" | head -n -1)

    log_debug "Pod response code: $http_code"
    log_debug "Pod response body: ${body:0:200}"

    if [[ "$http_code" != "200" ]]; then
        log_error "Pod returned HTTP $http_code"
        log_to_file "ERROR: Workflow submission failed: HTTP ${http_code}"

        # Try to extract error details from response
        local error_detail=$(echo "$body" | jq -r '.error // .errors // empty' 2>/dev/null)
        if [[ -n "$error_detail" ]]; then
            log_error "Error detail: $error_detail"
            log_to_file "Error detail: $error_detail"
        else
            log_error "Response: $body"
            log_to_file "Response: $body"
        fi
        return 1
    fi

    # Extract prompt_id from response
    PROMPT_ID=$(echo "$body" | jq -r '.prompt_id // .number // empty' 2>/dev/null)

    if [[ -z "$PROMPT_ID" ]]; then
        log_error "Failed to get prompt_id from response"
        log_to_file "ERROR: Could not extract prompt_id from pod response"

        # Try to extract error message
        local error_msg=$(echo "$body" | jq -r '.error // .errors[0] // empty' 2>/dev/null)
        if [[ -n "$error_msg" ]]; then
            log_error "Error: $error_msg"
            log_to_file "Error: $error_msg"
        else
            log_error "Response: $body"
            log_to_file "Response: $body"
        fi
        return 1
    fi

    log_success "Workflow submitted! Prompt ID: $PROMPT_ID"
    log_to_file "Workflow submitted successfully. Prompt ID: ${PROMPT_ID}"

    return 0
}

# Poll remote pod for workflow completion
poll_remote_completion() {
    local poll_interval=2
    local max_polls=$((TIMEOUT_SECONDS / poll_interval))
    local poll_count=0
    local start_time=$(date +%s)

    log_info "Polling for workflow completion..."
    log_to_file "Starting to poll pod for completion (max ${TIMEOUT_SECONDS}s)"

    while (( poll_count < max_polls )); do
        # Fetch history
        local response
        response=$(curl -s -w "\n%{http_code}" \
            --connect-timeout 5 \
            --max-time 10 \
            "${POD_URL}/history/${PROMPT_ID}" 2>/dev/null || echo "")

        if [[ -z "$response" ]]; then
            log_warn "No response from pod, retrying..."
            sleep "$poll_interval"
            ((poll_count++))
            continue
        fi

        local http_code=$(echo "$response" | tail -n 1)
        local body=$(echo "$response" | head -n -1)

        # Check for execution errors in the response
        if [[ "$http_code" == "200" ]] && echo "$body" | jq -e ".\"$PROMPT_ID\".status" > /dev/null 2>&1; then
            # Check if there's an error status
            local status_str=$(echo "$body" | jq -r ".\"$PROMPT_ID\".status.status_str // empty" 2>/dev/null)

            if [[ "$status_str" == "error" ]]; then
                log_error "Workflow execution failed"
                log_to_file "ERROR: Workflow execution failed"
                extract_execution_errors "$body"
                return 1
            fi
        fi

        # Check if complete (has outputs and no errors)
        if [[ "$http_code" == "200" ]] && echo "$body" | jq -e ".\"$PROMPT_ID\".outputs" > /dev/null 2>&1; then
            log_success "Workflow completed!"
            log_to_file "Workflow completed successfully"
            handle_remote_response "$body"
            return 0
        fi

        # Progress update every 10 polls (every 20 seconds)
        if (( poll_count % 10 == 0 )); then
            local elapsed=$(($(date +%s) - start_time))
            log_info "Still processing... (${elapsed}s elapsed)"
            log_to_file "Still polling... (${elapsed}s elapsed)"
        fi

        sleep "$poll_interval"
        ((poll_count++))
    done

    log_error "Timeout after ${TIMEOUT_SECONDS}s"
    log_to_file "ERROR: Workflow timeout after ${TIMEOUT_SECONDS}s"

    # Save recovery file for later use
    if save_prompt_for_recovery "$PROMPT_ID" "$POD_URL"; then
        show_recovery_instructions "$PROMPT_ID" "$POD_URL" "$RECOVERY_FILE"
    fi

    return 2
}

# Extract and display execution errors from workflow history
extract_execution_errors() {
    local history="$1"

    log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_error "WORKFLOW EXECUTION ERROR"
    log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_to_file "WORKFLOW EXECUTION ERROR:"

    # Extract overall error message if present
    local error_msg=$(echo "$history" | jq -r ".\"$PROMPT_ID\".status.status_str // empty" 2>/dev/null)
    if [[ -n "$error_msg" ]]; then
        log_error "Status: $error_msg"
        log_to_file "Status: $error_msg"
    fi

    # Extract node-level errors
    local node_errors=$(echo "$history" | jq ".\"$PROMPT_ID\" | select(has(\"status\")) | .status.messages // empty" 2>/dev/null)
    if [[ -n "$node_errors" && "$node_errors" != "null" ]]; then
        log_error "Status Messages:"
        log_to_file "Status Messages:"
        echo "$node_errors" | jq -r '.[] // empty' 2>/dev/null | while read -r msg; do
            [[ -n "$msg" ]] && {
                log_error "  • $msg"
                log_to_file "  • $msg"
            }
        done
    fi

    # Extract node errors if available
    local node_errors=$(echo "$history" | jq ".\"$PROMPT_ID\" | select(has(\"status\")) | .status | select(has(\"nodes\")) | .nodes // empty" 2>/dev/null)
    if [[ -n "$node_errors" && "$node_errors" != "null" ]]; then
        log_error "Node Errors:"
        log_to_file "Node Errors:"
        echo "$node_errors" | jq -r 'to_entries[] | select(.value != null) | "\(.key): \(.value // "Unknown error")"' 2>/dev/null | while read -r node_error; do
            [[ -n "$node_error" ]] && {
                log_error "  • $node_error"
                log_to_file "  • $node_error"
            }
        done
    fi

    # If no detailed errors found, show the raw status
    if [[ -z "$node_errors" ]]; then
        local full_status=$(echo "$history" | jq ".\"$PROMPT_ID\".status // empty" 2>/dev/null)
        if [[ -n "$full_status" && "$full_status" != "null" ]]; then
            log_error "Full Status:"
            log_to_file "Full Status:"
            echo "$full_status" | jq -r '.' 2>/dev/null | while read -r line; do
                [[ -n "$line" ]] && {
                    log_error "  $line"
                    log_to_file "  $line"
                }
            done
        fi
    fi

    log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_to_file "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    return 1
}

# Handle remote workflow response
handle_remote_response() {
    local history="$1"

    log_debug "Processing workflow response..."

    # Store outputs for download
    if [[ -n "${history:-}" ]]; then
        WORKFLOW_OUTPUTS=$(echo "$history" | jq ".\"$PROMPT_ID\".outputs // empty" 2>/dev/null)
        if [[ -n "$WORKFLOW_OUTPUTS" ]]; then
            log_debug "Outputs extracted successfully"
            return 0
        fi
    fi

    log_warn "No outputs found in response"
    return 1
}

################################################################################
# IMAGE DOWNLOAD FUNCTIONS
################################################################################

# Get unique output path with conflict resolution
get_unique_output_path() {
    local base_path="$1"
    local output_path="$base_path"
    local counter=1

    # If file exists, append counter to filename before extension
    if [[ -f "$output_path" ]]; then
        local dir=$(dirname "$base_path")
        local filename=$(basename "$base_path")
        local ext="${filename##*.}"
        local name="${filename%.*}"

        # Try numbered versions
        while [[ -f "${dir}/${name}_${counter}.${ext}" ]]; do
            ((counter++))
        done

        output_path="${dir}/${name}_${counter}.${ext}"
        log_debug "File conflict detected, using: $output_path"
        log_to_file "File conflict resolved: renamed to $(basename "$output_path")"
    fi

    echo "$output_path"
}

# Download remote images to localhost
download_remote_images() {
    local outputs_json="$1"

    if [[ -z "$outputs_json" ]]; then
        log_warn "No outputs to download"
        return 0
    fi

    log_info "Downloading images from remote pod..."
    log_to_file "Starting image download from pod"

    # Create local output directory
    mkdir -p "$LOCAL_OUTPUT_FOLDER" || {
        log_error "Failed to create output directory: $LOCAL_OUTPUT_FOLDER"
        return 1
    }

    # Parse outputs and download each image
    # Use a temporary file to avoid subshell issues with while loop
    local temp_file=$(mktemp)
    local download_count=0
    local failed_count=0

    python3 << PYTHON_EOF > "$temp_file"
import json
import sys

try:
    outputs = json.loads('''$outputs_json''')

    for node_id, node_output in outputs.items():
        if 'images' in node_output:
            for img in node_output['images']:
                filename = img.get('filename', '')
                subfolder = img.get('subfolder', '')
                img_type = img.get('type', 'output')

                if filename:
                    print(f"{filename}|{subfolder}|{img_type}")
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_EOF

    # Read and process each line
    while IFS='|' read -r filename subfolder img_type; do
        [[ -z "$filename" ]] && continue

        if download_single_image "$filename" "$subfolder" "$img_type"; then
            ((download_count++))
        else
            ((failed_count++))
        fi
    done < "$temp_file"

    # Clean up temp file
    rm -f "$temp_file"

    if (( download_count > 0 )); then
        log_success "Downloaded $download_count image(s)"
        log_to_file "Successfully downloaded $download_count image(s)"
        if (( failed_count > 0 )); then
            log_warn "Note: $failed_count image(s) failed to download"
            log_to_file "WARNING: $failed_count image(s) failed to download"
        fi
        return 0
    else
        log_warn "No images found in outputs"
        log_to_file "WARNING: No images found in outputs JSON"
        return 0
    fi
}

# Download a single image from pod with retry
download_single_image() {
    local filename="$1"
    local subfolder="${2:-}"
    local img_type="${3:-output}"
    local max_retries=3
    local retry_count=0

    # URL encode the filename and subfolder
    local url="${POD_URL}/view?filename=$(printf '%s' "$filename" | jq -sRr @uri)&type=$(printf '%s' "$img_type" | jq -sRr @uri)"

    if [[ -n "$subfolder" ]]; then
        url="${url}&subfolder=$(printf '%s' "$subfolder" | jq -sRr @uri)"
    fi

    local output_path="${LOCAL_OUTPUT_FOLDER}${filename}"

    # Check for file conflicts and resolve
    output_path=$(get_unique_output_path "$output_path")

    log_debug "Downloading: $filename from $url"
    log_to_file "Downloading image: $filename -> $(basename "$output_path")"

    # Create parent directory if needed
    mkdir -p "$(dirname "$output_path")" 2>/dev/null || true

    # Retry logic for downloads
    while (( retry_count < max_retries )); do
        # Remove incomplete file before retry
        if (( retry_count > 0 )); then
            rm -f "$output_path" 2>/dev/null || true
            local backoff=$((retry_count))
            log_warn "Retrying download (attempt $((retry_count + 1))/$max_retries) after ${backoff}s..."
            sleep "$backoff"
        fi

        local curl_exit=0
        if curl -s -f -o "$output_path" \
            --connect-timeout 10 \
            --max-time 300 \
            "$url" 2>/dev/null; then
            curl_exit=0
        else
            curl_exit=$?
        fi

        if [[ $curl_exit -eq 0 ]]; then
            if verify_download "$output_path"; then
                log_success "Downloaded: $filename"
                log_to_file "Successfully downloaded: $filename"
                return 0
            else
                log_warn "Downloaded file may be incomplete: $filename (will retry)"
                log_to_file "WARNING: Downloaded file may be incomplete: $filename (will retry)"
            fi
        else
            log_warn "Download failed for $filename (curl exit: $curl_exit)"
            log_to_file "WARNING: Download attempt $((retry_count + 1))/$max_retries failed for $filename"
        fi

        ((retry_count++))
    done

    log_error "Download failed permanently after $max_retries attempts: $filename"
    log_to_file "ERROR: Failed to download $filename after $max_retries attempts"
    return 1
}

# Verify downloaded image is valid
verify_download() {
    local filepath="$1"

    # Check file exists and has size
    if [[ ! -s "$filepath" ]]; then
        log_warn "Downloaded file is empty: $filepath"
        return 1
    fi

    # Check PNG signature (89 50 4E 47)
    local header=$(xxd -l 4 -p "$filepath" 2>/dev/null || echo "")
    if [[ "$header" != "89504e47" ]]; then
        log_warn "File may not be a valid PNG: $filepath"
        return 1
    fi

    return 0
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    log_to_file "═══════════════════════════════════════════════════════════════"
    log_to_file "REMOTE EXECUTION START"
    log_to_file "═══════════════════════════════════════════════════════════════"

    # Verify dependencies
    verify_dependencies

    # Normalize pod URL
    POD_URL=$(normalize_pod_url "$POD_URL")
    log_info "Pod URL: ${POD_URL}"
    log_to_file "Pod URL: ${POD_URL}"

    # Check pod connectivity
    if ! retry_with_backoff check_remote_connectivity; then
        log_error "Cannot reach pod at ${POD_URL}"
        log_to_file "ERROR: Pod unreachable after retries"
        finalize_generation_log "Failed" "  Pod unreachable"
        exit 1
    fi

    # Process workflow
    local processed_workflow
    processed_workflow=$(process_workflow_template "$WORKFLOW_FILE")

    # Check if UI format
    if is_ui_format "$WORKFLOW_FILE"; then
        processed_workflow=$(convert_ui_to_api_format "$processed_workflow")
        log_debug "Converted workflow length: ${#processed_workflow}"
    fi

    log_debug "Workflow to validate: ${processed_workflow:0:100}"

    # Validate workflow
    if ! validate_workflow_structure "$processed_workflow"; then
        log_error "Workflow validation failed"
        log_to_file "ERROR: Workflow validation failed"
        finalize_generation_log "Failed" "  Workflow validation error"
        exit 1
    fi

    # Substitute seed
    processed_workflow=$(substitute_seed "$processed_workflow" "$SEED")

    # Submit workflow to pod
    if ! retry_with_backoff submit_remote_workflow "$processed_workflow"; then
        log_error "Failed to submit workflow to pod"
        log_to_file "ERROR: Workflow submission failed"
        finalize_generation_log "Failed" "  Workflow submission error"
        exit 1
    fi

    # Poll for completion
    if ! poll_remote_completion; then
        exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            finalize_generation_log "Timeout" "  Workflow timed out"
            exit 2
        else
            finalize_generation_log "Failed" "  Polling error"
            exit 1
        fi
    fi

    # Download images if enabled
    local output_details=""
    if [[ "$DOWNLOAD_IMAGES" == "true" ]]; then
        if download_remote_images "$WORKFLOW_OUTPUTS"; then
            output_details=$(ls -1 "$LOCAL_OUTPUT_FOLDER" 2>/dev/null | sed 's/^/  /' || echo "  (No files)")
        else
            log_warn "Image download encountered errors"
        fi
    else
        log_info "Image download disabled (--no-download)"
        log_to_file "Image download skipped (--no-download)"
        output_details="  (Download disabled)"
    fi

    # Finalize log
    finalize_generation_log "Success" "$output_details"

    log_success "Remote generation completed successfully!"
    return 0
}

# Run main function
main
