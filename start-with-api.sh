#!/bin/bash

################################################################################
# ComfyUI + REST API Startup Script
################################################################################
# Starts both ComfyUI and the REST API server
# Includes health checks, logging, and graceful shutdown handling
#
# Usage:
#   ./start-with-api.sh [--api-only] [--no-api]
#
# Options:
#   --api-only     Start only REST API (ComfyUI must be running separately)
#   --no-api       Start only ComfyUI (no REST API)
#   --debug        Enable debug logging
################################################################################

set -e

# Configuration
COMFYUI_HOST="${COMFYUI_HOST:-localhost}"
COMFYUI_PORT="${COMFYUI_PORT:-8188}"
API_HOST="${API_HOST:-0.0.0.0}"
API_PORT="${API_PORT:-5000}"
WORKSPACE_PATH="${WORKSPACE_PATH:-/workspace}"
DEBUG="${DEBUG:-false}"

# Script directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="${SCRIPT_DIR}/api"
COMFYUI_DIR="${WORKSPACE_PATH}/ComfyUI"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Utility Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $@"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $@"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $@"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $@"
}

wait_for_service() {
    local service_name=$1
    local host=$2
    local port=$3
    local max_attempts=30
    local attempt=0

    log_info "Waiting for ${service_name} to be ready..."

    while [ $attempt -lt $max_attempts ]; do
        if nc -z "$host" "$port" 2>/dev/null; then
            log_success "${service_name} is ready at ${host}:${port}"
            return 0
        fi

        attempt=$((attempt + 1))
        echo -n "."
        sleep 1
    done

    log_error "${service_name} failed to start (timeout after ${max_attempts}s)"
    return 1
}

cleanup() {
    log_info "Shutting down..."

    # Kill all background processes
    if [ -n "$COMFYUI_PID" ]; then
        log_info "Stopping ComfyUI (PID: $COMFYUI_PID)..."
        kill $COMFYUI_PID 2>/dev/null || true
    fi

    if [ -n "$API_PID" ]; then
        log_info "Stopping REST API (PID: $API_PID)..."
        kill $API_PID 2>/dev/null || true
    fi

    log_success "Shutdown complete"
    exit 0
}

################################################################################
# Main Script
################################################################################

# Parse command-line arguments
START_COMFYUI=true
START_API=true

for arg in "$@"; do
    case $arg in
        --api-only)
            START_COMFYUI=false
            log_info "Starting API only (ComfyUI must be running separately)"
            ;;
        --no-api)
            START_API=false
            log_info "Starting ComfyUI only (no REST API)"
            ;;
        --debug)
            DEBUG=true
            log_info "Debug mode enabled"
            ;;
        *)
            log_warning "Unknown option: $arg"
            ;;
    esac
done

# Register cleanup handler
trap cleanup SIGTERM SIGINT EXIT

log_info "=========================================="
log_info "ComfyUI + REST API Stack Startup"
log_info "=========================================="
log_info "ComfyUI: ${COMFYUI_HOST}:${COMFYUI_PORT}"
log_info "REST API: ${API_HOST}:${API_PORT}"
log_info "Workspace: ${WORKSPACE_PATH}"
log_info "Debug: ${DEBUG}"
log_info "=========================================="

################################################################################
# Start ComfyUI
################################################################################

if [ "$START_COMFYUI" = true ]; then
    log_info "Starting ComfyUI..."

    # Run the original start.sh script
    if [ -f "${SCRIPT_DIR}/start.sh" ]; then
        bash "${SCRIPT_DIR}/start.sh" &
        COMFYUI_PID=$!
        log_success "ComfyUI started (PID: $COMFYUI_PID)"
    else
        log_error "start.sh not found at ${SCRIPT_DIR}/start.sh"
        exit 1
    fi

    # Wait for ComfyUI to be ready
    if ! wait_for_service "ComfyUI" "$COMFYUI_HOST" "$COMFYUI_PORT"; then
        log_error "Failed to start ComfyUI"
        exit 1
    fi

    sleep 2  # Additional buffer for ComfyUI initialization
fi

################################################################################
# Start REST API
################################################################################

if [ "$START_API" = true ]; then
    log_info "Starting REST API..."

    # Check Python dependencies
    if ! python -c "import flask, requests" 2>/dev/null; then
        log_warning "Missing Python dependencies, installing..."
        pip install -q -r "${API_DIR}/requirements.txt"
    fi

    # Set environment variables for API
    export COMFYUI_HOST="$COMFYUI_HOST"
    export COMFYUI_PORT="$COMFYUI_PORT"
    export API_HOST="$API_HOST"
    export API_PORT="$API_PORT"
    export WORKSPACE_PATH="$WORKSPACE_PATH"
    [ "$DEBUG" = true ] && export DEBUG=true

    # Start the API
    if [ "$DEBUG" = true ]; then
        python "${API_DIR}/comfyui_rest_api.py" &
    else
        python "${API_DIR}/comfyui_rest_api.py" > /tmp/comfyui_api.log 2>&1 &
    fi

    API_PID=$!
    log_success "REST API started (PID: $API_PID)"

    # Wait for API to be ready
    if ! wait_for_service "REST API" "$API_HOST" "$API_PORT"; then
        log_error "Failed to start REST API"
        [ "$DEBUG" = false ] && log_error "Check logs: cat /tmp/comfyui_api.log"
        exit 1
    fi
fi

################################################################################
# Health Check
################################################################################

sleep 2

log_info "Running health checks..."

if [ "$START_COMFYUI" = true ]; then
    if curl -s "http://${COMFYUI_HOST}:${COMFYUI_PORT}/api/config" > /dev/null; then
        log_success "ComfyUI health check passed"
    else
        log_warning "ComfyUI health check failed"
    fi
fi

if [ "$START_API" = true ]; then
    if curl -s "http://${API_HOST}:${API_PORT}/api/health" > /dev/null; then
        log_success "REST API health check passed"
    else
        log_warning "REST API health check failed"
    fi
fi

################################################################################
# Running Services Summary
################################################################################

echo ""
log_success "All services started successfully!"
echo ""
echo -e "${GREEN}Available Endpoints:${NC}"

if [ "$START_COMFYUI" = true ]; then
    echo "  • ComfyUI Web UI:    http://${COMFYUI_HOST}:${COMFYUI_PORT}"
    echo "  • ComfyUI API:       http://${COMFYUI_HOST}:${COMFYUI_PORT}/api"
fi

if [ "$START_API" = true ]; then
    echo "  • REST API Health:   http://${API_HOST}:${API_PORT}/api/health"
    echo "  • Generate Image:    POST http://${API_HOST}:${API_PORT}/api/generate"
    echo "  • Check Status:      GET http://${API_HOST}:${API_PORT}/api/status/<job_id>"
    echo "  • List Outputs:      GET http://${API_HOST}:${API_PORT}/api/outputs"
fi

echo ""
log_info "Documentation:"
echo "  • REST API Guide:    documentation/REST_API_GUIDE.md"
echo "  • Flux.2 LoRA Guide: documentation/provisioning/hf_flux.2_turbo_lora.md"
echo ""

################################################################################
# Keep Running
################################################################################

log_info "Waiting for services to run (press Ctrl+C to stop)..."

# Wait for background processes
wait
