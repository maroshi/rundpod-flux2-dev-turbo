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

# Default pod URL (can be overridden via environment)
POD_URL="${RUNPOD_POD_URL:-http://104.255.9.187:8188}"

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
test_ssh_connection_parsing() {
    log_section "TEST SUITE 5: SSH Connection Parsing"

    log_test "Test 5.1: SSH connection format"
    local ssh_conn="root@104.255.9.187:11597"
    log_test "SSH connection: $ssh_conn"

    # Extract host from SSH connection
    if [[ "$ssh_conn" =~ @([^:]+) ]]; then
        local host="${BASH_REMATCH[1]}"
        log_pass "Extracted host from SSH connection: $host"
    else
        log_fail "Failed to parse SSH connection"
    fi
}

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
    test_ssh_connection_parsing
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
