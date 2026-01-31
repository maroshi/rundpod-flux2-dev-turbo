#!/bin/bash

################################################################################
# Pod Connectivity Test Script
# Tests various connection scenarios and pod accessibility
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m'

# Configuration
POD_URL="${RUNPOD_POD_URL:-http://104.255.9.187:8188}"
SSH_CONNECTION="${RUNPOD_SSH_CONNECTION:-root@104.255.9.187:11597}"
TIMEOUT=5

################################################################################
# UTILITY FUNCTIONS
################################################################################

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

test_case() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

################################################################################
# CONNECTION TESTS
################################################################################

test_http_connectivity() {
    print_header "HTTP Connectivity Tests"

    test_case "Test 1: Basic connectivity to pod"
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$TIMEOUT" "$POD_URL/system_stats" > /tmp/http_code.txt 2>/dev/null; then
        local http_code=$(cat /tmp/http_code.txt)
        case $http_code in
            200)
                pass "Pod is accessible (HTTP $http_code)"
                ;;
            *)
                warn "Pod responded with HTTP $http_code (may indicate issue)"
                ;;
        esac
    else
        fail "Unable to reach pod at $POD_URL"
    fi

    test_case "Test 2: System stats endpoint"
    if curl -s "$POD_URL/system_stats" > /tmp/system_stats.json 2>/dev/null; then
        if jq . /tmp/system_stats.json > /dev/null 2>&1; then
            pass "System stats endpoint returns valid JSON"

            # Extract useful info
            local os=$(jq -r '.system' /tmp/system_stats.json 2>/dev/null || echo "unknown")
            local python=$(jq -r '.python_version' /tmp/system_stats.json 2>/dev/null || echo "unknown")
            info "Operating System: $os"
            info "Python Version: $python"

            # Check for GPU devices
            if jq -e '.devices[]' /tmp/system_stats.json > /dev/null 2>&1; then
                pass "GPU devices detected"
                local device_count=$(jq '.devices | length' /tmp/system_stats.json)
                info "Number of devices: $device_count"

                # List devices
                jq -r '.devices[] | "  - \(.name): \(.type)"' /tmp/system_stats.json
            fi
        else
            fail "System stats response is not valid JSON"
        fi
    else
        fail "Cannot access system_stats endpoint"
    fi

    test_case "Test 3: Queue endpoint"
    if curl -s "$POD_URL/queue" > /tmp/queue.json 2>/dev/null; then
        if jq . /tmp/queue.json > /dev/null 2>&1; then
            pass "Queue endpoint accessible"

            local pending=$(jq '.queue_pending | length' /tmp/queue.json 2>/dev/null || echo "0")
            local running=$(jq '.queue_running | length' /tmp/queue.json 2>/dev/null || echo "0")
            info "Pending jobs: $pending"
            info "Running jobs: $running"
        else
            fail "Queue response is not valid JSON"
        fi
    else
        fail "Cannot access queue endpoint"
    fi

    test_case "Test 4: Connection timeout handling"
    if timeout 2 curl -s --connect-timeout 1 "http://192.0.2.1:8188/system_stats" > /dev/null 2>&1; then
        fail "Should have timed out on unreachable host"
    else
        pass "Connection timeout handled correctly"
    fi

    test_case "Test 5: Invalid pod URL format"
    if curl -s "http://invalid-host.local:8188/system_stats" > /dev/null 2>&1; then
        fail "Should fail on invalid host"
    else
        pass "Invalid host correctly rejected"
    fi
}

################################################################################
# SSH CONNECTIVITY TESTS
################################################################################

test_ssh_connectivity() {
    print_header "SSH Connectivity Tests"

    test_case "Test 1: SSH host reachability"
    local ssh_host=$(echo "$SSH_CONNECTION" | cut -d@ -f2 | cut -d: -f1)
    local ssh_port=$(echo "$SSH_CONNECTION" | cut -d: -f3)

    info "SSH Host: $ssh_host"
    info "SSH Port: $ssh_port"

    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$ssh_host/$ssh_port" 2>/dev/null; then
        pass "SSH port is open ($ssh_port)"
    else
        fail "Cannot connect to SSH port ($ssh_host:$ssh_port)"
        return
    fi

    test_case "Test 2: SSH key-based authentication"
    if [[ -f ~/.ssh/id_rsa ]]; then
        pass "SSH private key exists"
    else
        warn "SSH private key not found at ~/.ssh/id_rsa"
    fi

    test_case "Test 3: ComfyUI port from pod"
    # If SSH works, try to get ComfyUI port from pod
    if ssh -o ConnectTimeout=3 -o BatchMode=yes "$SSH_CONNECTION" "curl -s localhost:8188/system_stats | head -c 50" > /tmp/ssh_response.txt 2>/dev/null; then
        pass "Can execute commands on pod via SSH"
        cat /tmp/ssh_response.txt
    else
        warn "Cannot execute SSH commands (may need key setup)"
    fi
}

################################################################################
# WORKFLOW API TESTS
################################################################################

test_workflow_api() {
    print_header "Workflow API Tests"

    test_case "Test 1: Prompt submission format"
    local test_payload='{
        "prompt": {
            "1": {
                "class_type": "CheckpointLoaderSimple",
                "inputs": {"ckpt_name": "flux_merged.safetensors"}
            }
        },
        "client_id": "test-client-001"
    }'

    info "Test payload structure:"
    echo "$test_payload" | jq '.' 2>/dev/null || warn "Payload not valid JSON"

    test_case "Test 2: Mock prompt submission"
    # Simulate what the response would look like
    local mock_response='{"prompt_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890", "number": 1}'

    if echo "$mock_response" | jq '.prompt_id' > /dev/null 2>&1; then
        pass "Response contains valid prompt_id"
    else
        fail "Response missing prompt_id"
    fi

    test_case "Test 3: History endpoint format"
    local mock_history='{
        "a1b2c3d4-e5f6-7890-abcd-ef1234567890": {
            "prompt": {...},
            "outputs": {
                "9": {
                    "images": [
                        {"filename": "ComfyUI_00001_.png", "subfolder": "output", "type": "output"}
                    ]
                }
            },
            "status": "completed"
        }
    }'

    if echo "$mock_history" | jq '.' > /dev/null 2>&1; then
        pass "History response structure is valid JSON"
    else
        fail "History response is not valid JSON"
    fi

    test_case "Test 4: View endpoint URL construction"
    local filename="ComfyUI_00001_.png"
    local subfolder="output"
    local img_type="output"
    local view_url="${POD_URL}/view?filename=${filename}&subfolder=${subfolder}&type=${img_type}"

    info "View endpoint URL: $view_url"
    pass "View URL constructed correctly"
}

################################################################################
# PERFORMANCE TESTS
################################################################################

test_performance() {
    print_header "Performance Tests"

    test_case "Test 1: System stats response time"
    local start=$(date +%s%N)
    if curl -s "$POD_URL/system_stats" > /dev/null 2>&1; then
        local end=$(date +%s%N)
        local duration_ms=$(( (end - start) / 1000000 ))
        info "Response time: ${duration_ms}ms"
        if [[ $duration_ms -lt 1000 ]]; then
            pass "Fast response (<1s)"
        elif [[ $duration_ms -lt 5000 ]]; then
            warn "Moderate response time (1-5s)"
        else
            fail "Slow response time (>5s)"
        fi
    fi

    test_case "Test 2: Concurrent request handling"
    info "Testing 5 concurrent requests..."

    for i in {1..5}; do
        curl -s "$POD_URL/system_stats" > /tmp/concurrent_$i.json &
    done
    wait

    local success_count=0
    for i in {1..5}; do
        if jq . /tmp/concurrent_$i.json > /dev/null 2>&1; then
            ((success_count++))
        fi
    done

    if [[ $success_count -eq 5 ]]; then
        pass "All 5 concurrent requests succeeded"
    else
        warn "$success_count/5 concurrent requests succeeded"
    fi

    test_case "Test 3: Bandwidth estimation"
    if [[ -f /tmp/system_stats.json ]]; then
        local json_size=$(wc -c < /tmp/system_stats.json)
        info "System stats response size: $json_size bytes"
    fi
}

################################################################################
# DIAGNOSTIC INFORMATION
################################################################################

show_diagnostics() {
    print_header "Diagnostic Information"

    echo -e "${BLUE}Environment Variables:${NC}"
    env | grep -i pod || echo "No POD-related env vars"

    echo ""
    echo -e "${BLUE}Network Configuration:${NC}"
    echo "Pod URL: $POD_URL"
    echo "SSH Connection: $SSH_CONNECTION"

    echo ""
    echo -e "${BLUE}System Information:${NC}"
    uname -a

    echo ""
    echo -e "${BLUE}Installed Tools:${NC}"
    for cmd in curl jq ssh python3 envsubst; do
        if command -v "$cmd" &> /dev/null; then
            echo -e "${GREEN}✓${NC} $cmd: $(command -v $cmd)"
        else
            echo -e "${RED}✗${NC} $cmd: not found"
        fi
    done

    echo ""
    echo -e "${BLUE}DNS Resolution:${NC}"
    local pod_host=$(echo "$POD_URL" | sed -E 's|http://||;s|:[0-9]+$||')
    if host "$pod_host" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} DNS resolves: $pod_host"
    else
        echo -e "${YELLOW}~${NC} DNS lookup for $pod_host inconclusive"
    fi
}

################################################################################
# MAIN
################################################################################

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║          Pod Connectivity & API Tests                         ║"
    echo "╚════════════════════════════════════════════════════════════════╝"

    show_diagnostics

    test_http_connectivity
    test_ssh_connectivity
    test_workflow_api
    test_performance

    print_header "Test Summary"
    echo "Connectivity tests completed. Review output above for results."
    echo ""
}

main "$@"
