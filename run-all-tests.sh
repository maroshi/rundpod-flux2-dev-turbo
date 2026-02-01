#!/bin/bash

################################################################################
# Master Test Runner
# Runs all test suites and generates a comprehensive report
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_FILE="${SCRIPT_DIR}/test-report-$(date +%Y%m%d_%H%M%S).txt"
FAILED_TESTS=0
PASSED_TESTS=0
SKIPPED_TESTS=0

################################################################################
# UTILITY FUNCTIONS
################################################################################

print_banner() {
    echo ""
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║  $1${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$REPORT_FILE"
}

log_pass() {
    echo -e "${GREEN}[✓ PASS]${NC} $1" | tee -a "$REPORT_FILE"
    ((PASSED_TESTS++))
}

log_fail() {
    echo -e "${RED}[✗ FAIL]${NC} $1" | tee -a "$REPORT_FILE"
    ((FAILED_TESTS++))
}

log_skip() {
    echo -e "${YELLOW}[⊘ SKIP]${NC} $1" | tee -a "$REPORT_FILE"
    ((SKIPPED_TESTS++))
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

run_test_script() {
    local script_name="$1"
    local script_path="${SCRIPT_DIR}/${script_name}.sh"
    local description="$2"

    print_section "Running: $description"

    if [[ ! -f "$script_path" ]]; then
        log_fail "Script not found: $script_path"
        return 1
    fi

    log_info "Executing: $script_path"
    log_info "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"

    if bash "$script_path" 2>&1 | tee -a "$REPORT_FILE"; then
        log_pass "$description completed successfully"
        return 0
    else
        log_fail "$description failed (exit code: $?)"
        return 1
    fi
}

check_prerequisites() {
    print_section "Checking Prerequisites"

    local required_tools=("bash" "curl" "jq" "python3")
    local missing=0

    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_pass "Found: $tool"
        else
            log_fail "Missing: $tool"
            ((missing++))
        fi
    done

    if [[ $missing -gt 0 ]]; then
        log_info "Please install missing tools before running tests"
        return 1
    fi

    return 0
}

show_environment() {
    print_section "Test Environment"

    log_info "Script directory: $SCRIPT_DIR"
    log_info "Report file: $REPORT_FILE"
    log_info "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Pod URL: ${RUNPOD_POD_URL:-not set}"
    log_info "SSH Connection: ${RUNPOD_SSH_CONNECTION:-not set}"

    if [[ -f "${SCRIPT_DIR}/comfy-run-remote.sh" ]]; then
        log_pass "comfy-run-remote.sh exists"
    else
        log_skip "comfy-run-remote.sh not yet created (will be created later)"
    fi

    if [[ -f "${SCRIPT_DIR}/test/test-remote-runner.sh" ]]; then
        log_pass "test-remote-runner.sh found"
    else
        log_fail "test-remote-runner.sh not found"
    fi
}

################################################################################
# TEST EXECUTION
################################################################################

run_all_tests() {
    local test_count=0
    local start_time=$(date +%s)

    # Test 1: Remote Runner (Comprehensive)
    if [[ -f "${SCRIPT_DIR}/test/test-remote-runner.sh" ]]; then
        run_test_script "test/test-remote-runner" "Comprehensive Test Suite" || true
        ((test_count++))
    fi

    # Test 2: Pod Connectivity
    if [[ -f "${SCRIPT_DIR}/test/test-pod-connectivity.sh" ]]; then
        run_test_script "test/test-pod-connectivity" "Pod Connectivity Tests" || true
        ((test_count++))
    fi

    # Test 3: Workflow API
    if [[ -f "${SCRIPT_DIR}/test/test-workflow-api.sh" ]]; then
        run_test_script "test/test-workflow-api" "Workflow API Tests" || true
        ((test_count++))
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    return $test_count
}

generate_summary() {
    print_section "Test Summary"

    local total=$((PASSED_TESTS + FAILED_TESTS + SKIPPED_TESTS))

    echo "" | tee -a "$REPORT_FILE"
    echo -e "${BLUE}Test Results:${NC}" | tee -a "$REPORT_FILE"
    echo -e "  ${GREEN}Passed:  $PASSED_TESTS${NC}" | tee -a "$REPORT_FILE"
    echo -e "  ${RED}Failed:  $FAILED_TESTS${NC}" | tee -a "$REPORT_FILE"
    echo -e "  ${YELLOW}Skipped: $SKIPPED_TESTS${NC}" | tee -a "$REPORT_FILE"
    echo -e "  ${BLUE}Total:   $total${NC}" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"

    # Success percentage
    if [[ $total -gt 0 ]]; then
        local pass_percent=$(( (PASSED_TESTS * 100) / total ))
        echo -e "  Success Rate: ${GREEN}${pass_percent}%${NC}" | tee -a "$REPORT_FILE"
    fi

    echo "" | tee -a "$REPORT_FILE"

    # Overall result
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}" | tee -a "$REPORT_FILE"
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}" | tee -a "$REPORT_FILE"
        return 1
    fi
}

show_recommendations() {
    print_section "Recommendations"

    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo "" | tee -a "$REPORT_FILE"
        echo -e "${YELLOW}Failed Tests - Actions Required:${NC}" | tee -a "$REPORT_FILE"
        echo "  1. Review test log: cat $REPORT_FILE" | tee -a "$REPORT_FILE"
        echo "  2. Check pod connectivity: bash test-pod-connectivity.sh" | tee -a "$REPORT_FILE"
        echo "  3. Verify pod URL is set: echo \$RUNPOD_POD_URL" | tee -a "$REPORT_FILE"
        echo "  4. Check pod status: runpodctl pod list" | tee -a "$REPORT_FILE"
    fi

    if [[ $SKIPPED_TESTS -gt 0 ]]; then
        echo "" | tee -a "$REPORT_FILE"
        echo -e "${YELLOW}Skipped Tests:${NC}" | tee -a "$REPORT_FILE"
        echo "  Usually means pod is not accessible or not running" | tee -a "$REPORT_FILE"
        echo "  To enable these tests:" | tee -a "$REPORT_FILE"
        echo "    1. Start pod: runpodctl pod start" | tee -a "$REPORT_FILE"
        echo "    2. Set pod URL: export RUNPOD_POD_URL=http://IP:8188" | tee -a "$REPORT_FILE"
        echo "    3. Re-run tests" | tee -a "$REPORT_FILE"
    fi

    echo "" | tee -a "$REPORT_FILE"
    echo -e "${GREEN}Next Steps:${NC}" | tee -a "$REPORT_FILE"
    echo "  1. Implement comfy-run-remote.sh (see .claude/plans/)" | tee -a "$REPORT_FILE"
    echo "  2. Run end-to-end workflow test" | tee -a "$REPORT_FILE"
    echo "  3. Compare output with local comfy-run.sh" | tee -a "$REPORT_FILE"
    echo "  4. Deploy to production" | tee -a "$REPORT_FILE"
}

show_file_structure() {
    print_section "Created Test Files"

    echo "" | tee -a "$REPORT_FILE"
    echo "Test Scripts:" | tee -a "$REPORT_FILE"

    local test_files=(
        "test-remote-runner.sh"
        "test-pod-connectivity.sh"
        "test-workflow-api.sh"
        "run-all-tests.sh"
    )

    for file in "${test_files[@]}"; do
        if [[ -f "${SCRIPT_DIR}/${file}" ]]; then
            local size=$(wc -l < "${SCRIPT_DIR}/${file}")
            echo -e "  ${GREEN}✓${NC} $file ($size lines)" | tee -a "$REPORT_FILE"
        fi
    done

    echo "" | tee -a "$REPORT_FILE"
    echo "Documentation:" | tee -a "$REPORT_FILE"

    local doc_files=(
        "TEST_VALUES.md"
        "RUN_TESTS.md"
    )

    for file in "${doc_files[@]}"; do
        if [[ -f "${SCRIPT_DIR}/${file}" ]]; then
            echo -e "  ${GREEN}✓${NC} $file" | tee -a "$REPORT_FILE"
        fi
    done

    echo "" | tee -a "$REPORT_FILE"
}

################################################################################
# MAIN
################################################################################

main() {
    print_banner "Master Test Runner - comfy-run-remote.sh"

    # Initialize report
    {
        echo "════════════════════════════════════════════════════════════════"
        echo "Test Report: $(date)"
        echo "════════════════════════════════════════════════════════════════"
        echo ""
    } > "$REPORT_FILE"

    # Check prerequisites
    if ! check_prerequisites; then
        log_fail "Prerequisites check failed"
        echo "" | tee -a "$REPORT_FILE"
        echo "Please install missing dependencies and try again" | tee -a "$REPORT_FILE"
        exit 1
    fi

    # Show environment
    show_environment

    # Show file structure
    show_file_structure

    # Run all tests
    log_info "Starting test execution..."
    run_all_tests

    # Generate summary
    generate_summary
    test_result=$?

    # Show recommendations
    show_recommendations

    # Final output
    print_section "Test Report Details"
    log_info "Full report saved to: $REPORT_FILE"
    log_info ""
    log_info "Quick view:"
    log_info "  tail -50 $REPORT_FILE"
    log_info ""
    log_info "Full report:"
    log_info "  cat $REPORT_FILE"

    echo "" | tee -a "$REPORT_FILE"
    echo "════════════════════════════════════════════════════════════════" | tee -a "$REPORT_FILE"
    echo "Test run complete at $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$REPORT_FILE"
    echo "════════════════════════════════════════════════════════════════" | tee -a "$REPORT_FILE"

    exit $test_result
}

main "$@"
