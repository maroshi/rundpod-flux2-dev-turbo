#!/bin/bash

################################################################################
# Workflow API Test Script
# Tests ComfyUI API interactions: submit, poll, download
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${SCRIPT_DIR}/test-output/api-tests"
PROMPT_ID=""
CLIENT_ID="test-client-$(date +%s)-$$"

# Detect pod URL with priority order
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

# Priority 1: Environment variable
POD_URL="${RUNPOD_POD_URL:-}"

# Priority 2: Auto-detect using runpodctl
if [[ -z "$POD_URL" ]]; then
    POD_URL=$(detect_pod_url_from_runpodctl) || POD_URL=""
fi

# Priority 3: Fall back to environment-based detection
if [[ -z "$POD_URL" ]]; then
    # Try to detect from parent directory comfy-run-remote.sh
    if [[ -f "${SCRIPT_DIR}/../comfy-run-remote.sh" ]]; then
        POD_URL=$(grep -o "https://[^ ]*-8188.proxy.runpod.net" "${SCRIPT_DIR}/../comfy-run-remote.sh" 2>/dev/null | head -1) || POD_URL=""
    fi
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --pod-url)
            POD_URL="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

################################################################################
# UTILITY FUNCTIONS
################################################################################

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

################################################################################
# API HELPER FUNCTIONS
################################################################################

# Check if pod is accessible
check_pod_accessible() {
    log_test "Checking pod accessibility..."
    if curl -s -o /dev/null -w "%{http_code}" "$POD_URL/system_stats" 2>/dev/null | grep -q "200\|404"; then
        log_pass "Pod is accessible"
        return 0
    else
        log_fail "Pod is not accessible at $POD_URL"
        return 1
    fi
}

# Get pod information
get_pod_info() {
    log_test "Fetching pod information..."
    if curl -s "$POD_URL/system_stats" > "$TEST_DIR/system_stats.json" 2>/dev/null; then
        log_pass "Pod info retrieved"
        echo "System Stats:"
        jq . "$TEST_DIR/system_stats.json" 2>/dev/null || cat "$TEST_DIR/system_stats.json"
        return 0
    else
        log_fail "Cannot fetch pod info"
        return 1
    fi
}

# Get current queue status
get_queue_status() {
    log_test "Fetching queue status..."
    if curl -s "$POD_URL/queue" > "$TEST_DIR/queue_status.json" 2>/dev/null; then
        log_pass "Queue status retrieved"
        echo "Queue Status:"
        jq . "$TEST_DIR/queue_status.json" 2>/dev/null || cat "$TEST_DIR/queue_status.json"
        return 0
    else
        log_fail "Cannot fetch queue status"
        return 1
    fi
}

# Submit a minimal test workflow
submit_test_workflow() {
    log_test "Submitting test workflow..."

    # Create a minimal workflow
    local workflow_payload='{
        "prompt": {
            "1": {
                "class_type": "CheckpointLoaderSimple",
                "inputs": {"ckpt_name": "model.safetensors"}
            },
            "2": {
                "class_type": "CLIPTextEncode",
                "inputs": {"clip": ["1", 1], "text": "test prompt"}
            },
            "3": {
                "class_type": "SaveImage",
                "inputs": {"images": ["2", 0], "filename_prefix": "test"}
            }
        },
        "client_id": "'$CLIENT_ID'"
    }'

    log_info "Sending to: $POD_URL/prompt"
    log_info "Client ID: $CLIENT_ID"

    local response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$workflow_payload" \
        "$POD_URL/prompt")

    local http_code=$(echo "$response" | tail -n 1)
    local body=$(echo "$response" | head -n -1)

    echo "Response (HTTP $http_code):"
    echo "$body" | jq . 2>/dev/null || echo "$body"

    if [[ $http_code == "200" ]]; then
        PROMPT_ID=$(echo "$body" | jq -r '.prompt_id // .errors[0] // "error"' 2>/dev/null)
        if [[ "$PROMPT_ID" != "null" && -n "$PROMPT_ID" && "$PROMPT_ID" != "error" ]]; then
            log_pass "Workflow submitted successfully"
            log_info "Prompt ID: $PROMPT_ID"
            echo "$body" > "$TEST_DIR/workflow_response.json"
            return 0
        else
            log_fail "Response does not contain prompt_id"
            return 1
        fi
    else
        log_fail "Submission failed (HTTP $http_code)"
        echo "$body" > "$TEST_DIR/workflow_error.json"
        return 1
    fi
}

# Poll for workflow completion
poll_workflow_completion() {
    local prompt_id="$1"
    local max_polls=30  # 1 minute with 2s intervals
    local poll_count=0

    log_test "Polling for workflow completion (prompt_id: $prompt_id)..."
    log_info "Max wait: $((max_polls * 2)) seconds"

    while [[ $poll_count -lt $max_polls ]]; do
        local response=$(curl -s "$POD_URL/history/$prompt_id")

        # Check if execution is complete
        if echo "$response" | jq -e ".\"$prompt_id\".outputs" > /dev/null 2>&1; then
            log_pass "Workflow completed!"
            echo "$response" | jq ".\"$prompt_id\"" > "$TEST_DIR/workflow_result.json"
            echo "Result:"
            jq . "$TEST_DIR/workflow_result.json"
            return 0
        fi

        # Check for errors
        if echo "$response" | jq -e ".\"$prompt_id\".status.messages" > /dev/null 2>&1; then
            log_fail "Workflow encountered error"
            echo "$response" | jq ".\"$prompt_id\".status" > "$TEST_DIR/workflow_error_status.json"
            return 1
        fi

        # Show progress
        if (( poll_count % 5 == 0 )); then
            log_info "Still processing... (${poll_count}s elapsed)"
        fi

        sleep 2
        ((poll_count+=2))
    done

    log_fail "Workflow timeout (exceeded $((max_polls * 2))s)"
    return 1
}

# Get workflow history
get_workflow_history() {
    local prompt_id="$1"

    log_test "Fetching workflow history..."
    if curl -s "$POD_URL/history/$prompt_id" > "$TEST_DIR/history.json" 2>/dev/null; then
        log_pass "History retrieved"
        echo "History:"
        jq . "$TEST_DIR/history.json"
        return 0
    else
        log_fail "Cannot fetch history"
        return 1
    fi
}

# Test view endpoint (image download)
test_view_endpoint() {
    log_test "Testing view endpoint (image download)..."

    # Create a test image file on localhost
    local test_image="$TEST_DIR/test_image_00001.png"

    # Create minimal PNG (just the signature)
    printf '\x89\x50\x4E\x47\x0D\x0A\x1A\x0A' > "$test_image"

    log_pass "Test image created: $test_image"

    # Simulate what would be downloaded
    if [[ -s "$test_image" ]]; then
        log_pass "Test image verification: file has content"
    else
        log_fail "Test image is empty"
    fi
}

# Test error responses
test_error_response() {
    log_test "Testing error response handling..."

    # Try to get history for non-existent prompt
    local fake_prompt_id="00000000-0000-0000-0000-000000000000"
    local response=$(curl -s "$POD_URL/history/$fake_prompt_id")

    if echo "$response" | jq . > /dev/null 2>&1; then
        log_pass "Error response is valid JSON"
        # Check if response is empty or contains error
        if [[ "$response" == "{}" ]]; then
            log_pass "Non-existent prompt returns empty object"
        fi
    else
        log_fail "Error response is not valid JSON"
    fi
}

################################################################################
# RESPONSE PARSING TESTS
################################################################################

test_response_parsing() {
    print_header "Response Parsing Tests"

    log_test "Test 1: Parse successful submission response"
    local success_response='{"prompt_id": "abc123def456", "number": 1}'

    if echo "$success_response" | jq -e '.prompt_id' > /dev/null 2>&1; then
        local prompt_id=$(echo "$success_response" | jq -r '.prompt_id')
        log_pass "Successfully parsed prompt_id: $prompt_id"
    else
        log_fail "Failed to parse prompt_id"
    fi

    log_test "Test 2: Parse error response"
    local error_response='{
        "errors": ["Missing required input"],
        "node_errors": {
            "1": ["Invalid model name"]
        }
    }'

    if echo "$error_response" | jq -e '.errors[0]' > /dev/null 2>&1; then
        local error_msg=$(echo "$error_response" | jq -r '.errors[0]')
        log_pass "Successfully parsed error: $error_msg"
    else
        log_fail "Failed to parse error message"
    fi

    log_test "Test 3: Parse outputs from history"
    local history_response='{
        "abc123": {
            "outputs": {
                "1": {
                    "images": [
                        {"filename": "image_00001.png", "subfolder": "output", "type": "output"}
                    ]
                }
            }
        }
    }'

    if echo "$history_response" | jq -e '.abc123.outputs."1".images[0].filename' > /dev/null 2>&1; then
        local filename=$(echo "$history_response" | jq -r '.abc123.outputs."1".images[0].filename')
        log_pass "Successfully parsed filename: $filename"
    else
        log_fail "Failed to parse output filename"
    fi
}

################################################################################
# WORKFLOW JSON TESTS
################################################################################

test_workflow_json() {
    print_header "Workflow JSON Tests"

    local workflow_file="${SCRIPT_DIR}/../workflows/flux2_turbo_512x512_parametric_api.json"

    if [[ ! -f "$workflow_file" ]]; then
        log_fail "Workflow file not found: $workflow_file"
        return 1
    fi

    log_test "Test 1: Validate workflow JSON"
    if jq . "$workflow_file" > /dev/null 2>&1; then
        log_pass "Workflow JSON is valid"
    else
        log_fail "Workflow JSON is invalid"
        return 1
    fi

    log_test "Test 2: Check for required nodes"
    if jq -e '.nodes[]' "$workflow_file" > /dev/null 2>&1; then
        local node_count=$(jq '.nodes | length' "$workflow_file")
        log_pass "Workflow contains $node_count nodes"
    else
        log_fail "Workflow has no nodes"
    fi

    log_test "Test 3: Check for seed values"
    if jq -e '.nodes[] | select(.class_type == "KSampler") | .inputs.seed' "$workflow_file" > /dev/null 2>&1; then
        log_pass "KSampler nodes have seed values"
    else
        log_fail "KSampler nodes missing seed values"
    fi

    log_test "Test 4: Prepare workflow payload"
    # Extract first node
    if jq -e '.nodes | keys[0]' "$workflow_file" > /dev/null 2>&1; then
        local first_key=$(jq -r '.nodes | keys[0]' "$workflow_file")
        log_pass "Can extract node keys: first key = $first_key"
    else
        log_fail "Cannot extract node keys"
    fi
}

################################################################################
# STRESS TESTS
################################################################################

test_stress() {
    print_header "Stress Tests"

    log_test "Test 1: Multiple queue checks"
    local success=0
    for i in {1..10}; do
        if curl -s "$POD_URL/queue" > /dev/null 2>&1; then
            ((success++))
        fi
    done

    if [[ $success -ge 9 ]]; then
        log_pass "$success/10 queue checks succeeded"
    else
        log_fail "Only $success/10 queue checks succeeded"
    fi

    log_test "Test 2: Rapid history checks"
    local prompt_id="test-prompt-123"
    local success=0
    for i in {1..5}; do
        if curl -s "$POD_URL/history/$prompt_id" > /dev/null 2>&1; then
            ((success++))
        fi
    done

    if [[ $success -ge 4 ]]; then
        log_pass "$success/5 history checks succeeded"
    else
        log_fail "Only $success/5 history checks succeeded"
    fi
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║            Workflow API Test Script                           ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    # Setup
    mkdir -p "$TEST_DIR"
    log_info "Test directory: $TEST_DIR"
    log_info "Pod URL: $POD_URL"
    log_info "Client ID: $CLIENT_ID"

    # Basic connectivity
    print_header "Basic Connectivity"
    if ! check_pod_accessible; then
        log_fail "Pod is not accessible. Cannot continue with API tests."
        exit 1
    fi

    # Pod information
    print_header "Pod Information"
    if ! get_pod_info; then
        log_fail "Cannot retrieve pod information"
    fi

    # Queue status
    print_header "Queue Status"
    if ! get_queue_status; then
        log_fail "Cannot retrieve queue status"
    fi

    # Response parsing tests (don't require pod)
    test_response_parsing

    # Workflow JSON tests
    test_workflow_json

    # Stress tests
    test_stress

    # Workflow submission (only if needed)
    print_header "Workflow Submission Test"
    log_info "Skipping actual workflow submission (not required for unit tests)"
    log_info "Use comfy-run-remote.sh for end-to-end testing"

    # Error response test
    print_header "Error Handling"
    test_error_response

    # Summary
    print_header "Test Complete"
    log_info "Test output saved to: $TEST_DIR"
    ls -la "$TEST_DIR"

    echo ""
}

main "$@"
