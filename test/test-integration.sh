#!/bin/bash

###############################################################################
# Phase 2: Integration Tests - comfy-run-remote.sh
#
# Tests full workflow execution with image downloads to verify
# end-to-end functionality.
#
# Prerequisites:
#   - Pod must be running and accessible
#   - RUNPOD_POD_URL environment variable set or --pod-url provided
#   - comfy-run-remote.sh script must exist
#
# Usage:
#   bash test-integration.sh
#   bash test-integration.sh --pod-url "https://pod-id-8188.proxy.runpod.net"
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
REMOTE_SCRIPT="${SCRIPT_DIR}/../comfy-run-remote.sh"
OUTPUT_DIR="${TMPDIR:-/tmp}/test_integration_output_$$"
LOG_FILE="${TMPDIR:-/tmp}/test-integration-results_$$.log"
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
    print_header "PHASE 2: INTEGRATION TESTS - SETUP"

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

    # Check pod URL provided
    if [[ -z "$POD_URL" ]]; then
        log_fail "Pod URL not provided. Set RUNPOD_POD_URL or use --pod-url"
        exit 1
    fi
    log_pass "Pod URL configured: $POD_URL"

    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    log_pass "Output directory created: $OUTPUT_DIR"

    # Check pod connectivity
    log_test "Checking pod connectivity..."
    if curl -s --connect-timeout 5 "${POD_URL}/system_stats" > /dev/null 2>&1; then
        log_pass "Pod is accessible"
    else
        log_skip "Pod not accessible - skipping integration tests"
        exit 0
    fi
}

# Test 2.1: Full Workflow Execution
test_full_execution() {
    print_header "TEST 2.1: FULL WORKFLOW EXECUTION"

    local test_id="integration_001"
    local test_output="${OUTPUT_DIR}/test_2_1"
    mkdir -p "$test_output"

    log_test "Executing: Full workflow with seed=42"

    if [[ "$DEBUG" == "1" ]]; then
        "$REMOTE_SCRIPT" \
            --pod-url "$POD_URL" \
            --prompt "A red car on a sunny street" \
            --image-id "$test_id" \
            --seed 42 \
            --local-output "$test_output" 2>&1 | tee -a "$LOG_FILE"
    else
        if "$REMOTE_SCRIPT" \
            --pod-url "$POD_URL" \
            --prompt "A red car on a sunny street" \
            --image-id "$test_id" \
            --seed 42 \
            --local-output "$test_output" >> "$LOG_FILE" 2>&1; then
            log_pass "Script executed successfully"
        else
            log_fail "Script execution failed"
            return 1
        fi
    fi

    # Check for output files (including in subdirectories)
    if find "$test_output" -name "*.png" -type f | grep -q .; then
        local file_count=$(find "$test_output" -name "*.png" -type f | wc -l)
        log_pass "Images downloaded: $file_count file(s)"

        # Check file sizes
        local min_size=$((50 * 1024))  # 50KB minimum
        local all_valid=true

        while IFS= read -r file; do
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            if [[ $size -gt $min_size ]]; then
                log_pass "File valid: $(basename "$file") ($((size / 1024))KB)"
            else
                log_fail "File too small: $(basename "$file") ($size bytes)"
                all_valid=false
            fi
        done < <(find "$test_output" -name "*.png" -type f)

        if [[ "$all_valid" == "true" ]]; then
            return 0
        else
            return 1
        fi
    else
        log_fail "No PNG files found in output directory"
        return 1
    fi
}

# Test 2.2: Multiple Concurrent Submissions
test_concurrent_submissions() {
    print_header "TEST 2.2: MULTIPLE CONCURRENT SUBMISSIONS"

    local test_output="${OUTPUT_DIR}/test_2_2"
    mkdir -p "$test_output"

    log_test "Submitting 3 concurrent workflows..."

    local pids=()
    for i in {1..3}; do
        (
            "$REMOTE_SCRIPT" \
                --pod-url "$POD_URL" \
                --prompt "Test image $i" \
                --image-id "concurrent_$i" \
                --seed $((1000 + i)) \
                --local-output "$test_output" >> "$LOG_FILE" 2>&1
        ) &
        pids+=($!)
    done

    # Wait for all submissions
    local failed=0
    for pid in "${pids[@]}"; do
        if wait "$pid"; then
            :
        else
            ((failed++))
        fi
    done

    if [[ $failed -eq 0 ]]; then
        log_pass "All 3 submissions completed"
    else
        log_fail "$failed out of 3 submissions failed"
        return 1
    fi

    # Check for output files (including in subdirectories)
    local file_count=$(find "$test_output" -name "*.png" -type f | wc -l)
    if [[ $file_count -ge 3 ]]; then
        log_pass "Generated $file_count images (expected ≥3)"
        return 0
    elif [[ $file_count -gt 0 ]]; then
        log_fail "Generated only $file_count images (expected ≥3)"
        return 1
    else
        log_fail "No PNG files found in output directory"
        return 1
    fi
}

# Test 2.3: Download Verification
test_download_verification() {
    print_header "TEST 2.3: DOWNLOAD VERIFICATION"

    local test_id="verify_001"
    local test_output="${OUTPUT_DIR}/test_2_3"
    mkdir -p "$test_output"

    log_test "Executing: Workflow for download verification"

    if "$REMOTE_SCRIPT" \
        --pod-url "$POD_URL" \
        --prompt "Download verification test" \
        --image-id "$test_id" \
        --local-output "$test_output" >> "$LOG_FILE" 2>&1; then
        log_pass "Workflow executed"
    else
        log_fail "Workflow execution failed"
        return 1
    fi

    # Verify PNG magic bytes
    local all_valid=true
    while IFS= read -r file; do
        local magic=$(xxd -l 4 -p "$file" 2>/dev/null || od -An -tx1 -N4 "$file" | tr -d ' \n')
        # PNG magic bytes: 89 50 4E 47
        if [[ "$magic" == *"89504e47"* ]] || [[ "$magic" == *"89 50 4e 47"* ]]; then
            log_pass "Valid PNG: $(basename "$file")"
        else
            log_fail "Invalid PNG signature: $(basename "$file") (got: $magic)"
            all_valid=false
        fi
    done < <(ls "$test_output"/*.png 2>/dev/null || true)

    if [[ "$all_valid" == "true" ]] && ls "$test_output"/*.png > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Test 2.4: Progress Polling Verification
test_progress_polling() {
    print_header "TEST 2.4: PROGRESS POLLING VERIFICATION"

    local test_id="progress_001"
    local test_output="${OUTPUT_DIR}/test_2_4"
    local polling_log="${test_output}/polling.log"
    mkdir -p "$test_output"

    log_test "Executing with debug output to verify polling..."

    if DEBUG=1 "$REMOTE_SCRIPT" \
        --pod-url "$POD_URL" \
        --prompt "Progress test" \
        --image-id "$test_id" \
        --local-output "$test_output" > "$polling_log" 2>&1; then
        log_pass "Workflow executed"
    else
        log_fail "Workflow execution failed"
        return 1
    fi

    # Check for polling messages
    if grep -q "Still processing" "$polling_log" 2>/dev/null; then
        log_pass "Progress updates found in log"
    else
        log_skip "No progress updates in log (workflow completed too quickly)"
    fi

    # Check for polling interval consistency
    local poll_count=0
    if [[ -f "$polling_log" ]]; then
        poll_count=$(grep -c "poll" "$polling_log" 2>/dev/null | tr -d '\n' || echo 0)
    fi
    if [[ $poll_count -gt 0 ]]; then
        log_pass "Polling detected: $poll_count poll attempts"
        return 0
    else
        log_skip "No polling detected (workflow may have completed immediately)"
        return 0
    fi
}

# Cleanup
cleanup() {
    print_header "PHASE 2: TEST SUMMARY"

    echo "" | tee -a "$LOG_FILE"
    echo "Test Results:" | tee -a "$LOG_FILE"
    echo "  PASSED: $TESTS_PASSED" | tee -a "$LOG_FILE"
    echo "  FAILED: $TESTS_FAILED" | tee -a "$LOG_FILE"
    echo "  SKIPPED: $TESTS_SKIPPED" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_pass "All tests passed!"
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
    test_full_execution || true
    test_concurrent_submissions || true
    test_download_verification || true
    test_progress_polling || true

    cleanup
}

main "$@"
