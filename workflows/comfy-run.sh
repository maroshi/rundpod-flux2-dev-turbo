#!/bin/bash
# =============================================================================
# ComfyUI Workflow Runner with Parameter Injection and Logging
# =============================================================================
# Self-contained script for running ComfyUI workflows with parameters
# Location: ./rundpod-flux2-dev-turbo/workflows/comfy-run.sh
# Execution: Via SSH from Claude Code
#
# Usage:
#   ./comfy-run.sh --prompt "Your prompt text" [--image-id "id"] [--output-folder "path"] [--workflow file.json]
#
# Requirements:
#   - ComfyUI running at localhost:8188
#   - Workflow file with ${PROMPT}, ${IMAGE_ID}, and ${OUTPUT_FOLDER} placeholders
#   - curl, jq, envsubst (auto-installed if missing)
# =============================================================================

set -euo pipefail

# =============================================================================
# Inline Logging Functions (no external dependencies)
# =============================================================================

log_info() {
    echo "[INFO] $*"
}

log_success() {
    echo "[✓] $*"
}

log_error() {
    echo "[✗] $*" >&2
}

# =============================================================================
# Generation Logging Functions
# =============================================================================

init_generation_log() {
    # Create log directory if it doesn't exist
    mkdir -p "$GENERATION_LOG_DIR"

    # Create log file for this generation
    LOG_FILE="${GENERATION_LOG_DIR}generation_${START_TIMESTAMP}.log"

    # Write header with timestamp and parameters
    cat > "$LOG_FILE" << EOF
================================================================================
GENERATION LOG - ${START_TIME}
================================================================================
Parameters:
  Timestamp: ${START_TIME}
  Prompt: ${PROMPT}
  Image ID: ${IMAGE_ID}
  Output Folder: ${OUTPUT_FOLDER}
  Workflow: ${WORKFLOW_FILE}
  Client ID: ${CLIENT_ID}

Execution Log:
EOF
}

log_to_file() {
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"
    fi
}

finalize_generation_log() {
    if [[ -n "${LOG_FILE:-}" ]]; then
        local END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
        cat >> "$LOG_FILE" << EOF

Generation Results:
  Completion Status: $1
  Prompt ID: ${PROMPT_ID}
  End Time: ${END_TIME}
  Output Location: ${OUTPUT_FOLDER}

Generated Images:
${2:-  (No output captured)"}

================================================================================
EOF
        log_info "Generation logged to: $LOG_FILE"
    fi
}

# =============================================================================
# Configuration (hardcoded for pod execution)
# =============================================================================

COMFYUI_HOST="localhost"
COMFYUI_PORT="8188"
COMFYUI_URL="http://${COMFYUI_HOST}:${COMFYUI_PORT}"

# Get script directory (where workflow files are located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
WORKFLOW_FILE="${SCRIPT_DIR}/flux2_turbo_512x512_parametric.json"
PROMPT=""
IMAGE_ID="UNDEFINED_ID_"
OUTPUT_FOLDER="/workspace/output/"
GENERATION_LOG_DIR="/workspace/logs/generations/"
PROMPT_ID=""  # Initialize early to avoid unbound variable errors

# Timestamp for this run
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
START_TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Generate unique client ID (needed for logging)
CLIENT_ID="claude-code-${START_TIMESTAMP}-$(date +%N)"

# =============================================================================
# Argument Parsing
# =============================================================================

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
        *)
            log_error "Unknown option: $1"
            echo "Usage: $0 --prompt \"text\" [--image-id \"id\"] [--output-folder \"path\"] [--workflow file.json]"
            exit 1
            ;;
    esac
done

# =============================================================================
# Validation
# =============================================================================

# Validate required arguments FIRST
if [[ -z "$PROMPT" ]]; then
    log_error "Prompt is required"
    echo "Usage: $0 --prompt \"text\" [--image-id \"id\"] [--workflow file.json]"
    exit 1
fi

# AFTER validation succeeds, export environment variables for envsubst
export PROMPT
export IMAGE_ID
export OUTPUT_FOLDER

# Verify workflow file exists
if [[ ! -f "$WORKFLOW_FILE" ]]; then
    echo "[✗] Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

log_info "Using workflow: $WORKFLOW_FILE"
log_info "Using prompt: $PROMPT"
log_info "Using image-id: $IMAGE_ID"
log_info "Using output-folder: $OUTPUT_FOLDER"

# Initialize generation log
init_generation_log
log_to_file "Generation started with parameters"

# =============================================================================
# Dependency Checks
# =============================================================================

# Check curl
if ! command -v curl &> /dev/null; then
    echo "[✗] curl not found - cannot proceed"
    exit 1
fi

# Check jq
if ! command -v jq &> /dev/null; then
    echo "[✗] jq not found - cannot proceed"
    exit 1
fi

# Check envsubst - auto-install if missing
if ! command -v envsubst &> /dev/null; then
    log_info "envsubst not found, installing gettext-base..."
    if apt-get update && apt-get install -y gettext-base > /dev/null 2>&1; then
        log_success "envsubst installed successfully"
    else
        echo "[✗] Failed to install envsubst (gettext-base package)"
        exit 1
    fi
fi

# =============================================================================
# ComfyUI Accessibility Check
# =============================================================================

log_info "Checking ComfyUI server accessibility..."
log_to_file "Checking ComfyUI server accessibility at ${COMFYUI_URL}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${COMFYUI_URL}/system_stats")
if [[ "$HTTP_CODE" != "200" ]]; then
    echo "[✗] ComfyUI server not accessible at ${COMFYUI_URL} (HTTP $HTTP_CODE)"
    log_to_file "ERROR: ComfyUI server not accessible (HTTP $HTTP_CODE)"
    finalize_generation_log "Failed" ""
    exit 1
fi
log_success "ComfyUI server is accessible"
log_to_file "ComfyUI server is accessible"

# =============================================================================
# Validate Workflow Structure
# =============================================================================

log_info "Validating workflow structure..."
log_to_file "Validating workflow structure"
if ! jq -e '.nodes[] | select(.type == "CLIPTextEncode")' "$WORKFLOW_FILE" > /dev/null 2>&1; then
    echo "[✗] Workflow does not contain CLIPTextEncode node for prompt"
    log_to_file "ERROR: Workflow missing CLIPTextEncode node"
    finalize_generation_log "Failed" ""
    exit 1
fi

if ! jq -e '.nodes[] | select(.type == "SaveImage")' "$WORKFLOW_FILE" > /dev/null 2>&1; then
    echo "[✗] Workflow does not contain SaveImage node for output"
    log_to_file "ERROR: Workflow missing SaveImage node"
    finalize_generation_log "Failed" ""
    exit 1
fi
log_success "Workflow structure is valid"
log_to_file "Workflow structure validated successfully"

# =============================================================================
# Workflow Processing Functions
# =============================================================================

# Convert UI format workflow to API format for ComfyUI REST API
convert_ui_to_api_format() {
    local ui_workflow_file=$1
    local comfyui_url="${COMFYUI_URL:-http://localhost:8188}"

    # Use Python to convert UI format to API format
    python3 << PYTHON_EOF
import json
import urllib.request
import urllib.error

# Read the UI format workflow
with open("$ui_workflow_file", 'r') as f:
    ui_workflow = json.load(f)

# Try to fetch node definitions from ComfyUI API for proper input name mapping
node_definitions = {}
try:
    req = urllib.request.Request("$comfyui_url/object_info")
    with urllib.request.urlopen(req, timeout=5) as response:
        node_definitions = json.loads(response.read().decode())
except Exception as e:
    pass  # Continue without node definitions if API is unavailable

# Check if it's already in API format (has nodes as top-level keys)
if 'nodes' in ui_workflow and isinstance(ui_workflow['nodes'], list):
    # Build link mapping: link_id -> (source_node_id, output_slot)
    link_map = {}
    if 'links' in ui_workflow and ui_workflow['links']:
        for link in ui_workflow['links']:
            link_id, source_node, source_slot, target_node, target_slot, link_type = link[:6]
            link_map[link_id] = [str(source_node), source_slot]

    # Convert from UI format to API format
    api_workflow = {}

    # UI-only node types that should be filtered out
    ui_only_nodes = {'Note', 'Reroute', 'PrimitiveNode'}

    for node in ui_workflow['nodes']:
        node_id = str(node['id'])
        node_type = node.get('type')

        # Skip UI-only nodes
        if node_type in ui_only_nodes:
            continue

        api_node = {
            'class_type': node_type,
            'inputs': {}
        }

        # Process inputs (connections to other nodes)
        if 'inputs' in node and isinstance(node['inputs'], list):
            for input_item in node['inputs']:
                input_name = input_item.get('name', '')
                if 'link' in input_item and input_item['link'] is not None:
                    # This input is connected to another node
                    if input_item['link'] in link_map:
                        # Use the resolved link reference
                        api_node['inputs'][input_name] = link_map[input_item['link']]

        # Process widget values (parameters)
        if 'widgets_values' in node:
            widget_values = list(node['widgets_values'])  # Make a copy
            node_type = node.get('type', '')

            # Filter out UI-only widget values (e.g., "randomize" controls)
            # These shouldn't be sent to the API
            filtered_widget_values = []
            for val in widget_values:
                # Skip "randomize" control values
                if isinstance(val, str) and val == 'randomize':
                    continue
                filtered_widget_values.append(val)

            # Get input names from node definition if available
            input_names = []
            if node_type in node_definitions:
                node_def = node_definitions[node_type]
                if 'input' in node_def:
                    # Get required inputs in order
                    required = node_def.get('input', {}).get('required', {})
                    input_names = list(required.keys())

            # Map filtered widget values to input names
            if input_names:
                # Build list of unset input names (those that need widget values)
                unset_inputs = [name for name in input_names if name not in api_node['inputs']]

                # Assign widget values to unset inputs in order
                for idx, input_name in enumerate(unset_inputs):
                    if idx < len(filtered_widget_values):
                        api_node['inputs'][input_name] = filtered_widget_values[idx]
            else:
                # Fallback: no node definition, just map widget values generically
                for idx, widget_value in enumerate(filtered_widget_values):
                    api_node['inputs'][f'widget_{idx}'] = widget_value

        api_workflow[node_id] = api_node

    print(json.dumps(api_workflow))
else:
    # Already in API format, just return as is
    print(json.dumps(ui_workflow))
PYTHON_EOF
}

# =============================================================================
# Workflow Processing
# =============================================================================

log_info "Processing workflow with variable substitution..."
log_to_file "Processing workflow with variable substitution"

# Create temp file for processed workflow
TEMP_WORKFLOW=$(mktemp /tmp/comfyui-workflow-XXXXXX.json)
trap "rm -f $TEMP_WORKFLOW" EXIT

# Process template: read workflow file and substitute variables with consistent ${VAR} syntax
envsubst < "$WORKFLOW_FILE" > "$TEMP_WORKFLOW"
log_success "Workflow processed successfully"
log_to_file "Workflow processed with variable substitution"

# Convert from UI format to API format if needed
TEMP_WORKFLOW_API=$(mktemp /tmp/comfyui-workflow-api-XXXXXX.json)
convert_ui_to_api_format "$TEMP_WORKFLOW" > "$TEMP_WORKFLOW_API"
log_info "Workflow converted to API format"
log_to_file "Workflow converted to API format for REST API submission"

# =============================================================================
# Submit Workflow to ComfyUI
# =============================================================================

log_info "Submitting workflow to ComfyUI..."

# Client ID already generated at initialization
log_to_file "Submitting workflow with Client ID: ${CLIENT_ID}"

# Build the payload using the API-format workflow
PAYLOAD="{\"prompt\": $(cat "$TEMP_WORKFLOW_API"), \"client_id\": \"$CLIENT_ID\"}"

# Print the curl command for debugging
log_info "Curl command being executed:"
echo "curl -X POST \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '${PAYLOAD:0:200}...' \\"
echo "  \"${COMFYUI_URL}/prompt\""
echo ""

# Save full payload to file for debugging
PAYLOAD_FILE="/tmp/comfyui-payload-${START_TIMESTAMP}.json"
echo "$PAYLOAD" > "$PAYLOAD_FILE"
log_info "Full payload saved to: $PAYLOAD_FILE"

# Submit with HTTP status check
HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "${COMFYUI_URL}/prompt")

# Extract response body and status code
RESPONSE=$(echo "$HTTP_RESPONSE" | head -n -1)
STATUS_CODE=$(echo "$HTTP_RESPONSE" | tail -n 1)

# Check HTTP 200 status
if [[ "$STATUS_CODE" != "200" ]]; then
    echo "[✗] Failed to submit workflow (HTTP $STATUS_CODE): $RESPONSE"
    log_to_file "ERROR: Failed to submit workflow (HTTP $STATUS_CODE): $RESPONSE"
    log_to_file "Full payload was: $PAYLOAD_FILE"
    finalize_generation_log "Failed" ""
    exit 1
fi

# Extract prompt_id - set to empty string if not found
PROMPT_ID=$(echo "$RESPONSE" | jq -r '.prompt_id' 2>/dev/null || echo "")

if [[ -z "$PROMPT_ID" || "$PROMPT_ID" == "null" ]]; then
    echo "[✗] Failed to get prompt_id from response: $RESPONSE"
    log_to_file "ERROR: Failed to extract prompt_id from response: $RESPONSE"
    finalize_generation_log "Failed" ""
    exit 1
fi

log_success "Workflow submitted successfully (prompt_id: $PROMPT_ID)"
log_to_file "Workflow submitted successfully with prompt_id: ${PROMPT_ID}"

# =============================================================================
# Poll for Completion
# =============================================================================

log_info "Waiting for workflow completion..."

POLL_INTERVAL=2
POLL_COUNT=0
MAX_POLLS=1800  # 1 hour at 2-second intervals

while [[ $POLL_COUNT -lt $MAX_POLLS ]]; do
    # Fetch history with HTTP status check
    HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" "${COMFYUI_URL}/history/${PROMPT_ID}")
    HISTORY=$(echo "$HTTP_RESPONSE" | head -n -1)
    STATUS_CODE=$(echo "$HTTP_RESPONSE" | tail -n 1)

    # Check HTTP 200 status
    if [[ "$STATUS_CODE" != "200" ]]; then
        echo "[✗] Failed to fetch workflow status (HTTP $STATUS_CODE)"
        log_to_file "ERROR: Failed to fetch workflow status (HTTP $STATUS_CODE)"
        finalize_generation_log "Failed" ""
        exit 1
    fi

    # Check if prompt_id exists in history (means completed)
    if echo "$HISTORY" | jq -e ".\"$PROMPT_ID\"" > /dev/null 2>&1; then
        # Check for errors in execution
        if echo "$HISTORY" | jq -e ".\"$PROMPT_ID\".outputs" > /dev/null 2>&1; then
            log_success "Workflow completed successfully"
            log_to_file "Workflow execution completed successfully"

            # Extract output information
            OUTPUTS=$(echo "$HISTORY" | jq ".\"$PROMPT_ID\".outputs" 2>/dev/null)
            echo "$OUTPUTS"

            # Finalize log with successful completion
            finalize_generation_log "Success" "$OUTPUTS"
            exit 0
        else
            # Workflow failed - extract error message if available
            ERROR_MSG=$(echo "$HISTORY" | jq -r ".\"$PROMPT_ID\".status.messages // \"Unknown error\"" 2>/dev/null)
            echo "[✗] Workflow execution failed: $ERROR_MSG"
            log_to_file "ERROR: Workflow execution failed: $ERROR_MSG"
            finalize_generation_log "Failed" "$ERROR_MSG"
            exit 1
        fi
    fi

    # Show progress every 10 polls (20 seconds)
    if (( POLL_COUNT % 10 == 0 )); then
        ELAPSED=$((POLL_COUNT * POLL_INTERVAL))
        log_info "Still processing... (${ELAPSED}s elapsed)"
        log_to_file "Still processing... (${ELAPSED}s elapsed)"
    fi

    sleep $POLL_INTERVAL
    ((POLL_COUNT++))
done

# Timeout reached
echo "[✗] Workflow did not complete within timeout period"
log_to_file "ERROR: Workflow did not complete within timeout period (${MAX_POLLS} polls)"
finalize_generation_log "Timeout" ""
exit 1
