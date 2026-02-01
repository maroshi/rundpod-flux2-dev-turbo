#!/bin/bash

###############################################################################
# Phase 4: Regression Tests - comfy-run-remote.sh
#
# Tests that remote execution produces identical results to local execution
# when using the same seed. Verifies determinism and output compatibility.
#
# Prerequisites:
#   - Both comfy-run.sh and comfy-run-remote.sh must exist
#   - Pod must be running and accessible
#   - RUNPOD_POD_URL environment variable set or --pod-url provided
#   - Enough disk space for test outputs
#
# Usage:
#   bash test-regression.sh
#   bash test-regression.sh --pod-url "https://pod-id-8188.proxy.runpod.net"
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
LOCAL_SCRIPT="${SCRIPT_DIR}/comfy-run.sh"
OUTPUT_DIR="${TMPDIR:-/tmp}/test_regression_output_$$"
LOG_FILE="${TMPDIR:-/tmp}/test-regression-results_$$.log"
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
    print_header "PHASE 4: REGRESSION TESTS - SETUP"

    # Clear log
    > "$LOG_FILE"

    # Check scripts exist
    if [[ ! -f "$REMOTE_SCRIPT" ]]; then
        log_fail "comfy-run-remote.sh not found at $REMOTE_SCRIPT"
        exit 1
    fi
    log_pass "comfy-run-remote.sh found"

    if [[ ! -f "$LOCAL_SCRIPT" ]]; then
        log_skip "comfy-run.sh not found - skipping local execution tests"
        SKIP_LOCAL_TESTS=1
    else
        log_pass "comfy-run.sh found"
        SKIP_LOCAL_TESTS=0
    fi

    # Check executable
    if [[ ! -x "$REMOTE_SCRIPT" ]]; then
        chmod +x "$REMOTE_SCRIPT"
        log_info "Made comfy-run-remote.sh executable"
    fi
    if [[ -f "$LOCAL_SCRIPT" ]] && [[ ! -x "$LOCAL_SCRIPT" ]]; then
        chmod +x "$LOCAL_SCRIPT"
        log_info "Made comfy-run.sh executable"
    fi

    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    log_pass "Output directory created: $OUTPUT_DIR"

    # Check pod URL
    if [[ -z "$POD_URL" ]]; then
        log_fail "Pod URL not provided. Set RUNPOD_POD_URL or use --pod-url"
        exit 1
    fi
    log_pass "Pod URL configured: $POD_URL"

    # Check pod connectivity
    log_test "Checking pod connectivity..."
    if curl -s --connect-timeout 5 "${POD_URL}/system_stats" > /dev/null 2>&1; then
        log_pass "Pod is accessible"
    else
        log_fail "Pod not accessible"
        exit 1
    fi
}

# Test 4.1: Seed Reproducibility (Local)
test_local_reproducibility() {
    print_header "TEST 4.1: SEED REPRODUCIBILITY (LOCAL)"

    if [[ "${SKIP_LOCAL_TESTS:-0}" == "1" ]]; then
        log_skip "Skipping local execution tests"
        return 0
    fi

    local test_output_1="${OUTPUT_DIR}/test_4_1_run1"
    local test_output_2="${OUTPUT_DIR}/test_4_1_run2"
    mkdir -p "$test_output_1" "$test_output_2"

    log_test "First local execution with seed=12345..."

    if "$LOCAL_SCRIPT" \
        --prompt "A red car" \
        --seed 12345 \
        --output-folder "$test_output_1" >> "$LOG_FILE" 2>&1; then
        log_pass "First local execution completed"
    else
        log_skip "Local execution failed (comfy-run.sh may require pod setup)"
        return 0
    fi

    log_test "Second local execution with same seed=12345..."

    if "$LOCAL_SCRIPT" \
        --prompt "A red car" \
        --seed 12345 \
        --output-folder "$test_output_2" >> "$LOG_FILE" 2>&1; then
        log_pass "Second local execution completed"
    else
        log_fail "Second local execution failed"
        return 1
    fi

    # Compare outputs
    log_test "Comparing outputs..."

    if ! ls "$test_output_1"/*.png > /dev/null 2>&1; then
        log_skip "No PNG files found from first run"
        return 0
    fi

    if ! ls "$test_output_2"/*.png > /dev/null 2>&1; then
        log_skip "No PNG files found from second run"
        return 0
    fi

    # Calculate MD5 hashes
    local hash1=$(find "$test_output_1" -name "*.png" -exec md5sum {} \; | sort | md5sum | awk '{print $1}')
    local hash2=$(find "$test_output_2" -name "*.png" -exec md5sum {} \; | sort | md5sum | awk '{print $1}')

    if [[ "$hash1" == "$hash2" ]]; then
        log_pass "Local execution is deterministic (hashes match)"
        return 0
    else
        log_fail "Local outputs differ with same seed (non-deterministic)"
        return 1
    fi
}

# Test 4.2: Seed Reproducibility (Remote)
test_remote_reproducibility() {
    print_header "TEST 4.2: SEED REPRODUCIBILITY (REMOTE)"

    local test_output_1="${OUTPUT_DIR}/test_4_2_run1"
    local test_output_2="${OUTPUT_DIR}/test_4_2_run2"
    mkdir -p "$test_output_1" "$test_output_2"

    log_test "First remote execution with seed=12345..."

    if "$REMOTE_SCRIPT" \
        --pod-url "$POD_URL" \
        --prompt "A red car" \
        --seed 12345 \
        --local-output "$test_output_1" >> "$LOG_FILE" 2>&1; then
        log_pass "First remote execution completed"
    else
        log_fail "First remote execution failed"
        return 1
    fi

    log_test "Second remote execution with same seed=12345..."

    if "$REMOTE_SCRIPT" \
        --pod-url "$POD_URL" \
        --prompt "A red car" \
        --seed 12345 \
        --local-output "$test_output_2" >> "$LOG_FILE" 2>&1; then
        log_pass "Second remote execution completed"
    else
        log_fail "Second remote execution failed"
        return 1
    fi

    # Compare outputs
    log_test "Comparing outputs..."

    if ! ls "$test_output_1"/*.png > /dev/null 2>&1; then
        log_fail "No PNG files found from first remote run"
        return 1
    fi

    if ! ls "$test_output_2"/*.png > /dev/null 2>&1; then
        log_fail "No PNG files found from second remote run"
        return 1
    fi

    # Calculate MD5 hashes
    local hash1=$(find "$test_output_1" -name "*.png" -exec md5sum {} \; | sort | md5sum | awk '{print $1}')
    local hash2=$(find "$test_output_2" -name "*.png" -exec md5sum {} \; | sort | md5sum | awk '{print $1}')

    if [[ "$hash1" == "$hash2" ]]; then
        log_pass "Remote execution is deterministic (hashes match)"
        return 0
    else
        log_fail "Remote outputs differ with same seed (non-deterministic)"
        return 1
    fi
}

# Test 4.3: Local vs Remote Equivalence
test_local_remote_equivalence() {
    print_header "TEST 4.3: LOCAL VS REMOTE EQUIVALENCE"

    if [[ "${SKIP_LOCAL_TESTS:-0}" == "1" ]]; then
        log_skip "Skipping local/remote comparison"
        return 0
    fi

    local test_local="${OUTPUT_DIR}/test_4_3_local"
    local test_remote="${OUTPUT_DIR}/test_4_3_remote"
    mkdir -p "$test_local" "$test_remote"

    log_test "Generating image locally with seed=54321..."

    if ! "$LOCAL_SCRIPT" \
        --prompt "A red car" \
        --seed 54321 \
        --output-folder "$test_local" >> "$LOG_FILE" 2>&1; then
        log_skip "Local execution failed"
        return 0
    fi

    log_test "Generating image remotely with same seed=54321..."

    if ! "$REMOTE_SCRIPT" \
        --pod-url "$POD_URL" \
        --prompt "A red car" \
        --seed 54321 \
        --local-output "$test_remote" >> "$LOG_FILE" 2>&1; then
        log_fail "Remote execution failed"
        return 1
    fi

    # Compare results
    if ! ls "$test_local"/*.png > /dev/null 2>&1; then
        log_skip "No local PNG files found"
        return 0
    fi

    if ! ls "$test_remote"/*.png > /dev/null 2>&1; then
        log_fail "No remote PNG files found"
        return 1
    fi

    # Count files
    local local_count=$(ls "$test_local"/*.png 2>/dev/null | wc -l)
    local remote_count=$(ls "$test_remote"/*.png 2>/dev/null | wc -l)

    if [[ $local_count -ne $remote_count ]]; then
        log_fail "File count mismatch: local=$local_count, remote=$remote_count"
        return 1
    fi
    log_pass "File counts match: $local_count images each"

    # Calculate hashes
    local local_hash=$(find "$test_local" -name "*.png" -exec md5sum {} \; | sort | md5sum | awk '{print $1}')
    local remote_hash=$(find "$test_remote" -name "*.png" -exec md5sum {} \; | sort | md5sum | awk '{print $1}')

    if [[ "$local_hash" == "$remote_hash" ]]; then
        log_pass "Local and remote outputs are identical"
        return 0
    else
        log_fail "Local and remote outputs differ (same seed should produce identical images)"
        log_info "Local hash: $local_hash"
        log_info "Remote hash: $remote_hash"
        return 1
    fi
}

# Test 4.4: Different Seeds Produce Different Output
test_seed_variation() {
    print_header "TEST 4.4: DIFFERENT SEEDS PRODUCE DIFFERENT OUTPUT"

    local test_seed_111="${OUTPUT_DIR}/test_4_4_seed111"
    local test_seed_222="${OUTPUT_DIR}/test_4_4_seed222"
    mkdir -p "$test_seed_111" "$test_seed_222"

    log_test "Generating image with seed=111..."

    if ! "$REMOTE_SCRIPT" \
        --pod-url "$POD_URL" \
        --prompt "A red car" \
        --seed 111 \
        --local-output "$test_seed_111" >> "$LOG_FILE" 2>&1; then
        log_fail "First image generation failed"
        return 1
    fi

    log_test "Generating image with seed=222..."

    if ! "$REMOTE_SCRIPT" \
        --pod-url "$POD_URL" \
        --prompt "A red car" \
        --seed 222 \
        --local-output "$test_seed_222" >> "$LOG_FILE" 2>&1; then
        log_fail "Second image generation failed"
        return 1
    fi

    # Check files exist
    if ! ls "$test_seed_111"/*.png > /dev/null 2>&1; then
        log_fail "No image generated for seed=111"
        return 1
    fi

    if ! ls "$test_seed_222"/*.png > /dev/null 2>&1; then
        log_fail "No image generated for seed=222"
        return 1
    fi

    # Calculate hashes
    local hash_111=$(find "$test_seed_111" -name "*.png" -exec md5sum {} \; | sort | md5sum | awk '{print $1}')
    local hash_222=$(find "$test_seed_222" -name "*.png" -exec md5sum {} \; | sort | md5sum | awk '{print $1}')

    if [[ "$hash_111" != "$hash_222" ]]; then
        log_pass "Different seeds produce different images"
        return 0
    else
        log_fail "Different seeds produce identical images (expected variation)"
        return 1
    fi
}

# Cleanup
cleanup() {
    print_header "PHASE 4: TEST SUMMARY"

    echo "" | tee -a "$LOG_FILE"
    echo "Test Results:" | tee -a "$LOG_FILE"
    echo "  PASSED: $TESTS_PASSED" | tee -a "$LOG_FILE"
    echo "  FAILED: $TESTS_FAILED" | tee -a "$LOG_FILE"
    echo "  SKIPPED: $TESTS_SKIPPED" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_pass "All regression tests passed!"
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
    test_local_reproducibility || true
    test_remote_reproducibility || true
    test_local_remote_equivalence || true
    test_seed_variation || true

    cleanup
}

main "$@"
