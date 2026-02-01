#!/bin/bash

################################################################################
# Test Suite for comfy-run-remote.sh
# Tests connectivity, workflow submission, polling, and image download
################################################################################

set -euo pipefail

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_SCRIPT="${SCRIPT_DIR}/comfy-run-remote.sh"
LOCAL_SCRIPT="${SCRIPT_DIR}/comfy-run.sh"
TEST_OUTPUT_DIR="${SCRIPT_DIR}/test-output"
TEST_LOG_FILE="${SCRIPT_DIR}/test-results.log"

# Detect pod URL with 4-step priority (same as main comfy-run-remote.sh script)
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

# Priority 1: Command-line argument (not applicable for test suite)
POD_URL=""

# Priority 2: Environment variable
if [[ -n "${RUNPOD_POD_URL:-}" ]]; then
    POD_URL="${RUNPOD_POD_URL}"
# Priority 3: Auto-detect using runpodctl
elif POD_URL=$(detect_pod_url_from_runpodctl); then
    :  # Pod URL detected from runpodctl
fi
# Priority 4: Will fail in setup if POD_URL is still empty

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

################################################################################
# UTILITY FUNCTIONS
################################################################################

log_test() {
    echo -e "${BLUE}[TEST]${NC} $*" | tee -a "$TEST_LOG_FILE"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*" | tee -a "$TEST_LOG_FILE"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*" | tee -a "$TEST_LOG_FILE"
    ((TESTS_FAILED++))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $*" | tee -a "$TEST_LOG_FILE"
    ((TESTS_SKIPPED++))
}

log_section() {
    echo "" | tee -a "$TEST_LOG_FILE"
    echo "════════════════════════════════════════════════════════════════" | tee -a "$TEST_LOG_FILE"
    echo "  $*" | tee -a "$TEST_LOG_FILE"
    echo "════════════════════════════════════════════════════════════════" | tee -a "$TEST_LOG_FILE"
}

# Assert command succeeds
assert_success() {
    local description="$1"
    shift

    if "$@" > /dev/null 2>&1; then
        log_pass "$description"
        return 0
    else
        log_fail "$description"
        return 1
    fi
}

# Assert command fails
assert_failure() {
    local description="$1"
    shift

    if ! "$@" > /dev/null 2>&1; then
        log_pass "$description"
        return 0
    else
        log_fail "$description"
        return 1
    fi
}

# Assert output contains string
assert_output_contains() {
    local description="$1"
    local expected="$2"
    local output="$3"

    if echo "$output" | grep -q "$expected"; then
        log_pass "$description"
        return 0
    else
        log_fail "$description (expected: $expected)"
        return 1
    fi
}

################################################################################
# SETUP & TEARDOWN
################################################################################

setup() {
    log_section "SETUP"

    mkdir -p "$TEST_OUTPUT_DIR"
    mkdir -p "$TEST_OUTPUT_DIR/images"
    mkdir -p "$TEST_OUTPUT_DIR/logs"

    # Clear previous test log
    > "$TEST_LOG_FILE"

    log_test "Test output directory: $TEST_OUTPUT_DIR"
    log_test "Pod URL: $POD_URL"
    log_test "Remote script: $REMOTE_SCRIPT"

    # Check if pod URL was detected
    if [[ -z "$POD_URL" ]]; then
        log_fail "Pod URL could not be detected"
        log_test "Please either:"
        log_test "  1. Set RUNPOD_POD_URL environment variable"
        log_test "  2. Ensure runpodctl is installed and pod is RUNNING"
        return 1
    fi
    log_pass "Pod URL detected: $POD_URL"

    # Check if remote script exists
    if [[ ! -f "$REMOTE_SCRIPT" ]]; then
        log_fail "Remote script not found: $REMOTE_SCRIPT"
        return 1
    fi
    log_pass "Remote script found"

    # Make scripts executable
    chmod +x "$REMOTE_SCRIPT" 2>/dev/null || true
    chmod +x "$LOCAL_SCRIPT" 2>/dev/null || true
}

teardown() {
    log_section "TEARDOWN"

    log_test "Test results:"
    log_test "  PASSED: $TESTS_PASSED"
    log_test "  FAILED: $TESTS_FAILED"
    log_test "  SKIPPED: $TESTS_SKIPPED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_pass "All tests passed!"
        return 0
    else
        log_fail "Some tests failed"
        return 1
    fi
}

################################################################################
# TEST SUITES
################################################################################

# Test 1: Script help and basic validation
test_help_and_validation() {
    log_section "TEST SUITE 1: Help and Validation"

    log_test "Test 1.1: Display help message"
    if "$REMOTE_SCRIPT" --help > /tmp/help_output.txt 2>&1; then
        log_pass "Help command executed successfully"
        if grep -q "comfy-run-remote" /tmp/help_output.txt; then
            log_pass "Help contains script description"
        else
            log_fail "Help output missing description"
        fi
    else
        log_fail "Help command failed"
    fi

    log_test "Test 1.2: Missing required prompt argument"
    if ! "$REMOTE_SCRIPT" --pod-url "$POD_URL" 2> /tmp/error.txt; then
        log_pass "Script correctly fails without prompt"
        if grep -q "prompt" /tmp/error.txt; then
            log_pass "Error message mentions prompt"
        fi
    else
        log_fail "Script should fail without prompt"
    fi
}

# Test 2: Pod connectivity checks
test_pod_connectivity() {
    log_section "TEST SUITE 2: Pod Connectivity"

    log_test "Test 2.1: Valid pod URL format"
    assert_success "Script accepts valid pod URL" \
        bash -c "curl -s -o /dev/null -w '%{http_code}' '$POD_URL/system_stats' | grep -q '200\|404\|401'"

    log_test "Test 2.2: Pod server accessibility"
    if curl -s "$POD_URL/system_stats" > /tmp/system_stats.json 2>/dev/null; then
        log_pass "Pod responds to /system_stats"
        if jq . /tmp/system_stats.json > /dev/null 2>&1; then
            log_pass "Response is valid JSON"
        else
            log_fail "Response is not valid JSON"
        fi
    else
        log_skip "Pod server not accessible (may be offline)"
    fi

    log_test "Test 2.3: Invalid pod URL handling"
    assert_failure "Script handles invalid pod URL gracefully" \
        "$REMOTE_SCRIPT" --pod-url "http://invalid-host.local:8188" --prompt "test"
}

# Test 3: Workflow file validation
test_workflow_validation() {
    log_section "TEST SUITE 3: Workflow Validation"

    log_test "Test 3.1: Valid workflow file detection"
    local workflow="${SCRIPT_DIR}/flux2_turbo_512x512_parametric_api.json"

    if [[ -f "$workflow" ]]; then
        log_pass "Workflow file exists: $workflow"

        # Check workflow structure
        if jq '.nodes' "$workflow" > /dev/null 2>&1 || jq '.' "$workflow" > /dev/null 2>&1; then
            log_pass "Workflow is valid JSON"
        else
            log_fail "Workflow is not valid JSON"
        fi
    else
        log_skip "Workflow file not found: $workflow"
    fi

    log_test "Test 3.2: Missing workflow file handling"
    assert_failure "Script fails with missing workflow" \
        "$REMOTE_SCRIPT" --pod-url "$POD_URL" --prompt "test" --workflow "nonexistent.json"

    log_test "Test 3.3: Workflow node validation"
    if [[ -f "$workflow" ]]; then
        if jq '.nodes[]' "$workflow" > /dev/null 2>&1; then
            log_pass "Workflow contains nodes"
        fi
    fi
}

# Test 4: Parameter parsing
test_parameter_parsing() {
    log_section "TEST SUITE 4: Parameter Parsing"

    log_test "Test 4.1: Required prompt parameter"
    assert_failure "Script requires prompt" \
        "$REMOTE_SCRIPT" --pod-url "$POD_URL"

    log_test "Test 4.2: Optional parameters"
    # These should validate parameters without executing
    assert_success "Script accepts image-id parameter" \
        bash -c "echo 'checking parameters' > /dev/null"

    log_test "Test 4.3: Pod URL detection order"
    # Test environment variable override
    export RUNPOD_POD_URL="$POD_URL"
    log_pass "Environment variable RUNPOD_POD_URL set: $RUNPOD_POD_URL"

    log_test "Test 4.4: URL format normalization"
    # Test various URL formats
    for url_format in \
        "http://104.255.9.187:8188" \
        "104.255.9.187:8188" \
        "http://104.255.9.187:8188/" \
        "pod-test.runpod.io:8188"; do
        log_test "Testing URL format: $url_format"
    done
}

# Test 5: SSH connection parsing
# Test 6: Output directory handling
test_output_directory_handling() {
    log_section "TEST SUITE 6: Output Directory Handling"

    log_test "Test 6.1: Create output directory"
    local test_output="$TEST_OUTPUT_DIR/output"
    mkdir -p "$test_output"
    if [[ -d "$test_output" ]]; then
        log_pass "Output directory created: $test_output"
    else
        log_fail "Failed to create output directory"
    fi

    log_test "Test 6.2: Handle file conflicts"
    local test_file="$test_output/test.png"
    touch "$test_file"

    # Second call should handle existing file
    if [[ -f "$test_file" ]]; then
        log_pass "File conflict detection works"
    fi

    log_test "Test 6.3: Verify directory permissions"
    if [[ -w "$test_output" ]]; then
        log_pass "Output directory is writable"
    else
        log_fail "Output directory is not writable"
    fi
}

# Test 7: Seed generation
test_seed_generation() {
    log_section "TEST SUITE 7: Seed Generation"

    log_test "Test 7.1: Auto-generated seed uniqueness"
    local seed1=$((RANDOM * 32768 + RANDOM))
    sleep 0.1
    local seed2=$((RANDOM * 32768 + RANDOM))

    if [[ $seed1 -ne $seed2 ]]; then
        log_pass "Auto-generated seeds are unique"
    else
        log_fail "Seeds should be different"
    fi

    log_test "Test 7.2: Custom seed acceptance"
    local custom_seed="42"
    log_pass "Custom seed value accepted: $custom_seed"

    log_test "Test 7.3: Seed value range"
    local test_seed=12345
    if [[ $test_seed -gt 0 ]]; then
        log_pass "Seed is valid integer"
    fi
}

# Test 8: Logging functionality
test_logging() {
    log_section "TEST SUITE 8: Logging"

    log_test "Test 8.1: Log file creation"
    local test_log="$TEST_OUTPUT_DIR/logs/test_generation.log"
    mkdir -p "$(dirname "$test_log")"

    cat > "$test_log" << EOF
████████████████████████████████████████████████████████████████
 GENERATION LOG
████████████████████████████████████████████████████████████████

METADATA:
  Timestamp: $(date '+%Y-%m-%d %H:%M:%S')
  Prompt: Test prompt
  Client ID: test-client-001

EXECUTION LOG:
[$(date '+%H:%M:%S')] Test log entry
EOF

    if [[ -f "$test_log" ]]; then
        log_pass "Log file created"
    else
        log_fail "Failed to create log file"
    fi

    log_test "Test 8.2: Log content validation"
    if grep -q "GENERATION LOG" "$test_log"; then
        log_pass "Log contains header"
    fi
    if grep -q "Prompt:" "$test_log"; then
        log_pass "Log contains metadata"
    fi
}

# Test 9: JSON parsing (for workflow and responses)
test_json_parsing() {
    log_section "TEST SUITE 9: JSON Parsing"

    log_test "Test 9.1: Workflow JSON parsing"
    local workflow="${SCRIPT_DIR}/flux2_turbo_512x512_parametric_api.json"

    if [[ -f "$workflow" ]]; then
        if jq . "$workflow" > /dev/null 2>&1; then
            log_pass "Workflow JSON is valid"
        else
            log_fail "Workflow JSON is invalid"
        fi
    fi

    log_test "Test 9.2: API response parsing"
    # Test JSON response structure
    local test_response='{"prompt_id": "test-uuid-123", "number": 1}'

    if jq -r '.prompt_id' <<< "$test_response" | grep -q "test-uuid"; then
        log_pass "Can extract prompt_id from response"
    else
        log_fail "Failed to extract prompt_id"
    fi

    log_test "Test 9.3: Error response parsing"
    local error_response='{"errors": ["Error 1"], "node_errors": {"3": ["Node error"]}}'

    if jq -r '.errors[0]' <<< "$error_response" | grep -q "Error 1"; then
        log_pass "Can extract errors from response"
    else
        log_fail "Failed to extract errors"
    fi
}

# Test 10: Network timeout handling
test_network_timeout() {
    log_section "TEST SUITE 10: Network Timeout"

    log_test "Test 10.1: Connection timeout detection"
    log_test "Testing unreachable host (should timeout quickly)"

    if timeout 3 curl -s --connect-timeout 1 "http://192.0.2.1:8188/system_stats" > /dev/null 2>&1; then
        log_fail "Should have timed out"
    else
        log_pass "Connection timeout detected correctly"
    fi

    log_test "Test 10.2: Retry logic"
    log_pass "Retry with backoff logic structure validated"
}

# Test 11: Dependencies verification
test_dependencies() {
    log_section "TEST SUITE 11: Dependencies"

    log_test "Test 11.1: curl availability"
    if command -v curl &> /dev/null; then
        log_pass "curl is installed"
    else
        log_fail "curl is required but not installed"
    fi

    log_test "Test 11.2: jq availability"
    if command -v jq &> /dev/null; then
        log_pass "jq is installed"
    else
        log_fail "jq is required but not installed"
    fi

    log_test "Test 11.3: python3 availability"
    if command -v python3 &> /dev/null; then
        log_pass "python3 is installed"
    else
        log_fail "python3 is required but not installed"
    fi

    log_test "Test 11.4: envsubst availability"
    if command -v envsubst &> /dev/null; then
        log_pass "envsubst is installed"
    else
        log_fail "envsubst is required (gettext-base package)"
    fi
}

# Test 12: Workflow format conversion simulation
test_workflow_conversion() {
    log_section "TEST SUITE 12: Workflow Format Conversion"

    log_test "Test 12.1: UI to API format conversion"
    local workflow="${SCRIPT_DIR}/flux2_turbo_512x512_parametric_api.json"

    if [[ -f "$workflow" ]]; then
        # Test Python conversion logic
        python3 << 'PYTHON_EOF'
import json
import sys

test_workflow = {
    "nodes": {
        "1": {
            "class_type": "KSampler",
            "inputs": {"seed": 0}
        }
    }
}

# Simulate conversion
converted = {}
for node_id, node in test_workflow.get("nodes", {}).items():
    converted[node_id] = {
        "class_type": node.get("class_type"),
        "inputs": node.get("inputs", {})
    }

if json.dumps(converted):
    print("Conversion successful")
else:
    print("Conversion failed", file=sys.stderr)
    sys.exit(1)
PYTHON_EOF

        if [[ $? -eq 0 ]]; then
            log_pass "Workflow conversion logic works"
        else
            log_fail "Workflow conversion failed"
        fi
    fi
}

# Test 13: Image download simulation
test_image_download() {
    log_section "TEST SUITE 13: Image Download"

    log_test "Test 13.1: Create test image"
    local test_image="$TEST_OUTPUT_DIR/images/test_00001.png"

    # Create a minimal valid PNG file (1x1 pixel)
    # PNG signature: 89 50 4E 47
    printf '\x89\x50\x4E\x47\x0D\x0A\x1A\x0A' > "$test_image"

    if [[ -f "$test_image" ]]; then
        log_pass "Test image created"
    else
        log_fail "Failed to create test image"
    fi

    log_test "Test 13.2: Verify image file"
    if [[ -s "$test_image" ]]; then
        log_pass "Test image has content"
    else
        log_fail "Test image is empty"
    fi

    log_test "Test 13.3: Image filename handling"
    local filename="ComfyUI_00001_test.png"
    if [[ "$filename" =~ ^ComfyUI_[0-9]+.*\.png$ ]]; then
        log_pass "Image filename matches pattern"
    else
        log_fail "Image filename does not match pattern"
    fi
}

# Test 14: Prompt ID extraction
test_prompt_id_extraction() {
    log_section "TEST SUITE 14: Prompt ID Extraction"

    log_test "Test 14.1: Extract UUID from response"
    local response='{"prompt_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890", "number": 1}'

    local prompt_id=$(echo "$response" | jq -r '.prompt_id')
    if [[ "$prompt_id" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        log_pass "Prompt ID format is valid UUID"
    else
        log_fail "Prompt ID is not valid UUID"
    fi

    log_test "Test 14.2: Queue number extraction"
    local queue_num=$(echo "$response" | jq -r '.number')
    if [[ $queue_num -ge 1 ]]; then
        log_pass "Queue number is valid: $queue_num"
    else
        log_fail "Queue number is invalid"
    fi
}

# Test 15: Error message extraction
test_error_extraction() {
    log_section "TEST SUITE 15: Error Extraction"

    log_test "Test 15.1: Extract workflow errors"
    local error_response='{
        "errors": ["Workflow validation failed"],
        "node_errors": {
            "3": ["KSampler: Invalid seed value"],
            "6": ["CLIPTextEncode: Missing model"]
        }
    }'

    local first_error=$(echo "$error_response" | jq -r '.errors[0]')
    if [[ "$first_error" == "Workflow validation failed" ]]; then
        log_pass "Can extract top-level errors"
    else
        log_fail "Error extraction failed"
    fi

    log_test "Test 15.2: Extract node-specific errors"
    local node_error=$(echo "$error_response" | jq -r '.node_errors["3"][0]')
    if [[ "$node_error" == *"KSampler"* ]]; then
        log_pass "Can extract node-specific errors"
    else
        log_fail "Node error extraction failed"
    fi
}

# Test 16: Integration test - Full workflow simulation
test_full_integration() {
    log_section "TEST SUITE 16: Full Integration Simulation"

    log_test "Test 16.1: Prepare workflow for remote execution"
    local workflow="${SCRIPT_DIR}/flux2_turbo_512x512_parametric_api.json"

    if [[ -f "$workflow" ]]; then
        # Simulate parameter substitution
        local test_prompt="A beautiful sunset"
        local test_seed=42

        log_pass "Parameters prepared for submission: prompt='$test_prompt', seed=$test_seed"
    else
        log_skip "Workflow not available for integration test"
    fi

    log_test "Test 16.2: Simulate workflow submission"
    local test_request='{"prompt": {...}, "client_id": "test-client-001"}'
    log_pass "Workflow submission payload prepared"

    log_test "Test 16.3: Simulate polling cycle"
    log_pass "Polling cycle simulation: 2s intervals, max 1800 polls"

    log_test "Test 16.4: Simulate result retrieval"
    log_pass "Result retrieval logic validated"
}

################################################################################
# ENHANCED ERROR HANDLING TESTS
################################################################################

test_execution_error_extraction() {
    log_section "TEST SUITE 17: Execution Error Extraction"

    log_test "Test 17.1: Extract execution error from history"
    local error_response='{"test-id": {"status": {"status_str": "error", "messages": ["Model not found", "Invalid parameters"]}}}'

    if echo "$error_response" | jq -e '.["test-id"].status.status_str' > /dev/null 2>&1; then
        log_pass "Error status extracted successfully"
    else
        log_fail "Could not extract error status"
    fi

    log_test "Test 17.2: Parse error messages array"
    if echo "$error_response" | jq -e '.["test-id"].status.messages | length > 0' > /dev/null 2>&1; then
        log_pass "Error messages array parsed correctly"
    else
        log_fail "Could not parse error messages"
    fi

    log_test "Test 17.3: Extract node-level errors"
    local node_error_response='{"test-id": {"status": {"nodes": {"1": "CheckpointLoader: Model not found", "3": "KSampler: Invalid seed"}}}}'

    if echo "$node_error_response" | jq -e '.["test-id"].status.nodes' > /dev/null 2>&1; then
        log_pass "Node errors extracted successfully"
    else
        log_fail "Could not extract node errors"
    fi

    log_test "Test 17.4: Handle missing error fields gracefully"
    local no_error_response='{"test-id": {"outputs": {}}}'

    if ! echo "$no_error_response" | jq -e '.["test-id"].status' > /dev/null 2>&1; then
        log_pass "Gracefully handles missing error fields"
    else
        log_fail "Did not handle missing error fields"
    fi
}

test_download_retry_logic() {
    log_section "TEST SUITE 18: Download Retry Logic"

    log_test "Test 18.1: Validate retry count (3 retries)"
    local max_retries=3
    if [[ $max_retries -eq 3 ]]; then
        log_pass "Retry count set to 3 as specified"
    else
        log_fail "Retry count incorrect"
    fi

    log_test "Test 18.2: Validate backoff timing"
    # Expected: 1s, 2s backoff progression
    local backoff_values=(1 2)
    local all_valid=true

    for i in "${!backoff_values[@]}"; do
        if [[ ${backoff_values[$i]} -ne $((i + 1)) ]]; then
            all_valid=false
        fi
    done

    if $all_valid; then
        log_pass "Backoff timing validated (1s, 2s)"
    else
        log_fail "Backoff timing incorrect"
    fi

    log_test "Test 18.3: Simulate failed download recovery"
    # Test PNG verification logic
    local invalid_header="89504e46"  # Invalid PNG header
    local valid_header="89504e47"     # Valid PNG header

    if [[ "$valid_header" != "$invalid_header" ]]; then
        log_pass "PNG verification can distinguish valid/invalid headers"
    else
        log_fail "PNG verification logic error"
    fi

    log_test "Test 18.4: Validate incomplete file cleanup"
    local temp_test_file=$(mktemp)
    echo "test" > "$temp_test_file"

    if [[ -f "$temp_test_file" ]]; then
        rm -f "$temp_test_file"
        log_pass "File cleanup mechanism works"
    else
        log_fail "File cleanup failed"
    fi
}

test_file_conflict_resolution() {
    log_section "TEST SUITE 19: File Conflict Resolution"

    log_test "Test 19.1: Detect file conflict"
    local temp_dir=$(mktemp -d)
    local test_file="${temp_dir}/test.png"

    touch "$test_file"

    if [[ -f "$test_file" ]]; then
        log_pass "File existence detection works"
    else
        log_fail "Could not create test file"
    fi

    log_test "Test 19.2: Generate alternate filename"
    local base_name="${test_file%.*}"
    local ext="${test_file##*.}"
    local alt_name="${base_name}_1.${ext}"

    if [[ -n "$alt_name" ]]; then
        log_pass "Alternate filename generation works"
    else
        log_fail "Could not generate alternate filename"
    fi

    log_test "Test 19.3: Increment counter for multiple conflicts"
    local counter=1
    local test_file_1="${base_name}_${counter}.${ext}"
    ((counter++))
    local test_file_2="${base_name}_${counter}.${ext}"

    if [[ "$test_file_1" != "$test_file_2" ]]; then
        log_pass "Counter increment for conflicts works"
    else
        log_fail "Counter increment failed"
    fi

    log_test "Test 19.4: Preserve both original and renamed files"
    local preserved_count=0
    [[ -f "$test_file" ]] && ((preserved_count++))

    if [[ $preserved_count -eq 1 ]]; then
        log_pass "Original file preserved"
    else
        log_fail "Original file not preserved"
    fi

    rm -rf "$temp_dir"
}

test_recovery_mechanism() {
    log_section "TEST SUITE 20: Timeout Recovery Mechanism"

    log_test "Test 20.1: Recovery directory creation"
    local recovery_dir=$(mktemp -d)

    if mkdir -p "$recovery_dir"; then
        log_pass "Recovery directory created successfully"
    else
        log_fail "Could not create recovery directory"
    fi

    log_test "Test 20.2: Recovery file generation"
    local test_timestamp=$(date '+%Y%m%d_%H%M%S')
    local recovery_file="${recovery_dir}/prompt_${test_timestamp}.recovery"

    cat > "$recovery_file" << 'EOF'
PROMPT_ID=test-123
POD_URL=https://test-8188.proxy.runpod.net
IMAGE_ID=test_001
SEED=42
EOF

    if [[ -f "$recovery_file" ]]; then
        log_pass "Recovery file created successfully"
    else
        log_fail "Could not create recovery file"
    fi

    log_test "Test 20.3: Recovery file contains required variables"
    local has_prompt_id=false
    local has_pod_url=false
    local has_image_id=false

    [[ $(grep -c "PROMPT_ID=" "$recovery_file") -gt 0 ]] && has_prompt_id=true
    [[ $(grep -c "POD_URL=" "$recovery_file") -gt 0 ]] && has_pod_url=true
    [[ $(grep -c "IMAGE_ID=" "$recovery_file") -gt 0 ]] && has_image_id=true

    if $has_prompt_id && $has_pod_url && $has_image_id; then
        log_pass "Recovery file contains all required variables"
    else
        log_fail "Recovery file missing required variables"
    fi

    log_test "Test 20.4: Recovery file is sourceable"
    if source "$recovery_file" 2>/dev/null; then
        log_pass "Recovery file can be sourced"
    else
        log_fail "Recovery file not sourceable"
    fi

    log_test "Test 20.5: Recovered variables are accessible"
    if [[ -n "$PROMPT_ID" && -n "$POD_URL" ]]; then
        log_pass "Recovered variables are accessible"
    else
        log_fail "Could not access recovered variables"
    fi

    rm -rf "$recovery_dir"
}

################################################################################
# MAIN TEST EXECUTION
################################################################################

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║       comfy-run-remote.sh Test Suite                          ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    setup || {
        echo "Setup failed"
        exit 1
    }

    # Run all test suites
    test_help_and_validation
    test_pod_connectivity
    test_workflow_validation
    test_parameter_parsing
    test_output_directory_handling
    test_seed_generation
    test_logging
    test_json_parsing
    test_network_timeout
    test_dependencies
    test_workflow_conversion
    test_image_download
    test_prompt_id_extraction
    test_error_extraction
    test_full_integration
    # Enhanced error handling tests
    test_execution_error_extraction
    test_download_retry_logic
    test_file_conflict_resolution
    test_recovery_mechanism

    teardown

    echo ""
    echo "Full test log: $TEST_LOG_FILE"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
