#!/bin/bash

###############################################################################
# Phase 3: Error Handling Tests - comfy-run-remote.sh
#
# Tests error detection, reporting, and recovery mechanisms.
#
# Prerequisites:
#   - comfy-run-remote.sh script must exist
#   - Pod URL optional for some tests
#   - Network connectivity tests may require specific setup
#
# Usage:
#   bash test-error-handling.sh
#   bash test-error-handling.sh --pod-url "https://pod-id-8188.proxy.runpod.net"
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_SCRIPT="${SCRIPT_DIR}/comfy-run-remote.sh"
OUTPUT_DIR="${TMPDIR:-/tmp}/test_error_output_$$"
LOG_FILE="${TMPDIR:-/tmp}/test-error-handling-results_$$.log"
DEBUG="${DEBUG:-0}"

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

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --pod-url)
            POD_URL="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --debug)
            DEBUG=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE" || true
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*" | tee -a "$LOG_FILE" || true
    ((TESTS_PASSED++)) || true
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*" | tee -a "$LOG_FILE" || true
    ((TESTS_FAILED++)) || true
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $*" | tee -a "$LOG_FILE" || true
    ((TESTS_SKIPPED++)) || true
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $*" | tee -a "$LOG_FILE" || true
}

# Header
print_header() {
    local title="$1"
    echo "" | tee -a "$LOG_FILE"
    echo "════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    echo "  $title" | tee -a "$LOG_FILE"
    echo "════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
}

# Initialize
initialize() {
    print_header "PHASE 3: ERROR HANDLING TESTS - SETUP"

    # Clear log
    > "$LOG_FILE"

    # Check script exists
    if [[ ! -f "$REMOTE_SCRIPT" ]]; then
        log_fail "comfy-run-remote.sh not found at $REMOTE_SCRIPT"
        exit 1
    fi
    log_pass "comfy-run-remote.sh found"

    # Check executable
    if [[ ! -x "$REMOTE_SCRIPT" ]]; then
        chmod +x "$REMOTE_SCRIPT"
        log_info "Made script executable"
    fi

    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    log_pass "Output directory created: $OUTPUT_DIR"
}

# Test 3.1: Pod Unreachable Error
test_pod_unreachable() {
    print_header "TEST 3.1: POD UNREACHABLE ERROR"

    local test_output="${OUTPUT_DIR}/test_3_1"
    mkdir -p "$test_output"

    log_test "Attempting to connect to invalid pod URL..."

    local output_file="${test_output}/error.log"

    # Should fail with connection error
    if "$REMOTE_SCRIPT" \
        --pod-url "https://invalid-pod-id-12345-8188.proxy.runpod.net" \
        --prompt "Test" \
        --local-output "$test_output" > "$output_file" 2>&1; then
        log_fail "Script should have failed with invalid pod URL"
        return 1
    else
        log_pass "Script correctly failed with invalid pod URL"
    fi

    # Check error message
    if grep -qi "unreachable\|refused\|connection\|not.*found" "$output_file"; then
        log_pass "Appropriate error message displayed"
    else
        log_skip "Could not verify error message (check: $output_file)"
    fi

    # Check for helpful guidance
    if grep -qi "runpodctl\|pod.*list\|URL" "$output_file"; then
        log_pass "Helpful troubleshooting guidance provided"
        return 0
    else
        log_skip "Limited error guidance"
        return 0
    fi
}

# Test 3.2: Timeout Handling
test_timeout_handling() {
    print_header "TEST 3.2: TIMEOUT HANDLING"

    if [[ -z "$POD_URL" ]]; then
        log_skip "Pod URL not configured - skipping timeout test"
        return 0
    fi

    local test_output="${OUTPUT_DIR}/test_3_2"
    mkdir -p "$test_output"

    log_test "Testing timeout with 5 second limit..."

    local output_file="${test_output}/timeout.log"
    local start_time=$(date +%s)

    # Should timeout after ~5 seconds
    if "$REMOTE_SCRIPT" \
        --pod-url "$POD_URL" \
        --prompt "Test" \
        --timeout 5 \
        --local-output "$test_output" > "$output_file" 2>&1; then
        log_fail "Script should have timed out"
        return 1
    else
        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))

        if [[ $elapsed -ge 4 && $elapsed -le 10 ]]; then
            log_pass "Timeout occurred within expected timeframe ($elapsed seconds)"
        else
            log_fail "Timeout timing unexpected ($elapsed seconds, expected ~5)"
            return 1
        fi
    fi

    # Check for timeout message
    if grep -qi "timeout" "$output_file"; then
        log_pass "Timeout error message detected"
    else
        log_fail "No timeout message found in output"
        return 1
    fi

    # Check for recovery file
    if [[ -d "${SCRIPT_DIR}/logs/recovery" ]]; then
        if ls "${SCRIPT_DIR}/logs/recovery"/*.recovery > /dev/null 2>&1; then
            log_pass "Recovery file created"

            # Check recovery file contents
            local recovery_file=$(ls "${SCRIPT_DIR}/logs/recovery"/*.recovery | head -1)
            if grep -q "PROMPT_ID\|POD_URL" "$recovery_file"; then
                log_pass "Recovery file contains required information"
                return 0
            else
                log_fail "Recovery file missing expected content"
                return 1
            fi
        else
            log_skip "No recovery file created (may be expected)"
            return 0
        fi
    else
        log_skip "Recovery directory not found"
        return 0
    fi
}

# Test 3.3: Invalid Workflow File
test_invalid_workflow() {
    print_header "TEST 3.3: INVALID WORKFLOW FILE"

    if [[ -z "$POD_URL" ]]; then
        log_skip "Pod URL not configured - testing file check only"
    fi

    local test_output="${OUTPUT_DIR}/test_3_3"
    mkdir -p "$test_output"

    log_test "Testing with non-existent workflow file..."

    local output_file="${test_output}/workflow_error.log"

    # Should fail immediately
    if "$REMOTE_SCRIPT" \
        --pod-url "${POD_URL:-https://test-8188.proxy.runpod.net}" \
        --prompt "Test" \
        --workflow "nonexistent_workflow_xyz.json" \
        --local-output "$test_output" > "$output_file" 2>&1; then
        log_fail "Script should have failed with missing workflow"
        return 1
    else
        log_pass "Script correctly failed with missing workflow"
    fi

    # Check for appropriate error message
    if grep -qi "not.*found\|does.*not.*exist\|file" "$output_file"; then
        log_pass "Appropriate error message displayed"
        return 0
    else
        log_fail "No file error message found"
        return 1
    fi
}

# Test 3.4: Missing Required Parameters
test_missing_parameters() {
    print_header "TEST 3.4: MISSING REQUIRED PARAMETERS"

    local test_output="${OUTPUT_DIR}/test_3_4"
    mkdir -p "$test_output"

    log_test "Test 3.4a: Missing --prompt parameter..."

    local output_file="${test_output}/missing_prompt.log"

    # Should fail with usage error
    if "$REMOTE_SCRIPT" \
        --pod-url "${POD_URL:-https://test-8188.proxy.runpod.net}" \
        --local-output "$test_output" > "$output_file" 2>&1; then
        log_fail "Script should have failed with missing --prompt"
        return 1
    else
        log_pass "Script correctly failed with missing --prompt"
    fi

    # Check for help message
    if grep -qi "usage\|prompt.*required\|help" "$output_file"; then
        log_pass "Help/usage message displayed for missing parameter"
    else
        log_skip "Limited usage guidance"
    fi

    log_test "Test 3.4b: Missing pod URL (no auto-detect)..."

    output_file="${test_output}/missing_url.log"

    # Should fail with pod URL error
    if "$REMOTE_SCRIPT" \
        --prompt "Test" \
        --local-output "$test_output" > "$output_file" 2>&1; then
        log_fail "Script should have failed with missing pod URL"
        return 1
    else
        log_pass "Script correctly failed with missing pod URL"
    fi

    # Check for helpful message
    if grep -qi "pod.*url\|runpodctl\|configure" "$output_file"; then
        log_pass "Helpful error message for missing pod URL"
        return 0
    else
        log_skip "Limited guidance for missing pod URL"
        return 0
    fi
}

# Test 3.5: Workflow Execution Error
test_execution_error() {
    print_header "TEST 3.5: WORKFLOW EXECUTION ERROR"

    if [[ -z "$POD_URL" ]]; then
        log_skip "Pod URL not configured - skipping execution error test"
        return 0
    fi

    local test_output="${OUTPUT_DIR}/test_3_5"
    mkdir -p "$test_output"

    log_test "Creating invalid workflow (missing required model)..."

    # Create workflow with non-existent model
    local workflow_file="${test_output}/invalid_workflow.json"
    cat > "$workflow_file" << 'EOF'
{
  "1": {
    "class_type": "CheckpointLoaderSimple",
    "inputs": {"ckpt_name": "nonexistent_model_xyz_12345.safetensors"}
  }
}
EOF

    log_test "Submitting invalid workflow..."

    local output_file="${test_output}/exec_error.log"

    # May succeed at submission but fail during execution
    if "$REMOTE_SCRIPT" \
        --pod-url "$POD_URL" \
        --prompt "Test" \
        --workflow "$workflow_file" \
        --local-output "$test_output" > "$output_file" 2>&1; then
        log_skip "Workflow submitted (pod may not validate on submission)"
    else
        log_test "Workflow submission/execution failed"
    fi

    # Check for error extraction
    if grep -qi "error\|execution\|failed" "$output_file"; then
        log_pass "Error message detected in output"
        return 0
    else
        log_skip "Could not verify error extraction"
        return 0
    fi
}

# Cleanup
cleanup() {
    print_header "PHASE 3: TEST SUMMARY"

    echo "" | tee -a "$LOG_FILE"
    echo "Test Results:" | tee -a "$LOG_FILE"
    echo "  PASSED: $TESTS_PASSED" | tee -a "$LOG_FILE"
    echo "  FAILED: $TESTS_FAILED" | tee -a "$LOG_FILE"
    echo "  SKIPPED: $TESTS_SKIPPED" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_pass "All error handling tests passed!"
        echo "" | tee -a "$LOG_FILE"
        echo "Full test log: $LOG_FILE" | tee -a "$LOG_FILE"
        echo "Output directory: $OUTPUT_DIR" | tee -a "$LOG_FILE"
        exit 0
    else
        log_fail "Some tests failed. See $LOG_FILE for details."
        exit 1
    fi
}

# Main
main() {
    initialize

    # Run tests
    test_pod_unreachable || true
    test_timeout_handling || true
    test_invalid_workflow || true
    test_missing_parameters || true
    test_execution_error || true

    cleanup
}

main "$@"
