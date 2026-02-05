# Implementation Plan: `comfy-run-remote.sh`

## Overview

Create a new script `comfy-run-remote.sh` that executes ComfyUI workflows remotely on RunPod instances from localhost. The script will handle remote submission, progress monitoring, and image download - all from the local machine.

**Location**: `/home/dudi/dev/image-generation-prompt/rundpod-flux2-dev-turbo/workflows/comfy-run-remote.sh`

## Design Architecture

### Pure Bash Implementation (Recommended)
- **Reuses 60%** of existing `comfy-run.sh` code
- **Dependencies**: curl, jq, python3, envsubst (same as local script)
- **No pod-side dependencies** - everything runs on localhost
- **HTTP polling** (not WebSocket) - simpler, sufficient for MVP

### Key Differences from `comfy-run.sh`

| Aspect | Local (`comfy-run.sh`) | Remote (`comfy-run-remote.sh`) |
|--------|------------------------|--------------------------------|
| Execution | Runs on pod | Runs on localhost |
| ComfyUI URL | localhost:8188 | https://{POD_ID}-8188.proxy.runpod.net |
| Workflow Processing | On pod | On localhost (then upload) |
| Image Output | Pod filesystem | Downloaded to localhost |
| Logging | Pod `/workspace/logs/` | Localhost `./logs/` |
| Dependencies | Pod packages | Localhost packages |

---

## Detailed Implementation Plan

### 1. Script Structure (4 Main Sections)

#### A. Configuration & Initialization (~350 lines)
**Reuse from comfy-run.sh**:
- Help system, logging functions, constants
- Argument parsing framework
- Dependency checking framework

**New for remote**:
```bash
# Remote-specific configuration
REMOTE_POD_URL=""              # e.g., https://{POD_ID}-8188.proxy.runpod.net
DOWNLOAD_IMAGES=true           # Enable/disable image download
TIMEOUT_SECONDS=3600           # Max execution time
LOCAL_OUTPUT_FOLDER="./output/" # Local download destination
LOCAL_LOG_DIR="./logs/generations/"
```

#### B. Connection Management (~200 lines) **NEW**
Functions to implement:
```bash
detect_pod_url()               # Auto-discover pod URL (4-step priority)
detect_pod_url_from_runpodctl() # Extract pod ID from runpodctl list
normalize_pod_url()            # Parse and validate URL format
check_remote_connectivity()    # Test HTTP connectivity to pod
get_pod_info()                 # Fetch /system_stats for validation
retry_with_backoff()           # Exponential backoff for network errors
```

**Connection Detection Priority**:
1. `--pod-url` parameter (highest priority)
2. `RUNPOD_POD_URL` environment variable
3. Auto-detect using `runpodctl pod list` (extracts pod ID and constructs proxy URL)
4. Fail with helpful error message (lowest priority)

#### C. Workflow Processing (~200 lines)
**Reuse 100% from comfy-run.sh**:
```bash
process_workflow_template()    # envsubst for ${PROMPT}, ${SEED}, etc.
convert_ui_to_api_format()     # Python UI→API format conversion
substitute_seed()              # KSampler seed injection
validate_workflow_structure()  # Check for required nodes
```

**Key**: All processing happens on localhost, then JSON is sent to pod

#### D. Remote Execution & Download (~350 lines) **NEW**
Functions to implement:
```bash
submit_remote_workflow()       # POST to ${POD_URL}/prompt
poll_remote_completion()       # GET ${POD_URL}/history/${PROMPT_ID}
handle_remote_response()       # Process success/error from remote
parse_outputs_json()           # Extract image metadata from history
download_remote_images()       # Download all images
download_single_image()        # GET ${POD_URL}/view?filename=...
verify_download()              # Verify image completeness
```

---

### 2. New Command-Line Parameters

**Remote-specific parameters**:
```bash
--pod-url URL                  # e.g., https://{POD_ID}-8188.proxy.runpod.net
--local-output PATH            # Local download destination (default: ./output/)
--download / --no-download     # Control image download
--timeout SECONDS              # Max execution time (default: 3600)
```

**Preserved from comfy-run.sh**:
```bash
--prompt TEXT                  # Required: generation prompt
--workflow FILE                # Workflow JSON file
--image-id ID                  # Unique identifier
--seed SEED                    # Random seed for reproducibility
--output-folder PATH           # REMOTE pod path (for workflow)
--help, -h                     # Show help
```

---

### 3. Core Implementation Details

### Pod URL Detection Implementation

**4-Step Priority Logic**:
```bash
# Priority 1: Command-line argument (highest priority)
if [[ -n "$POD_URL" ]]; then
    use $POD_URL
# Priority 2: Environment variable
elif [[ -n "${RUNPOD_POD_URL:-}" ]]; then
    POD_URL="${RUNPOD_POD_URL}"
# Priority 3: Auto-detect from runpodctl
elif POD_URL=$(detect_pod_url_from_runpodctl); then
    log_debug "Auto-detected pod URL from runpodctl: $POD_URL"
# Priority 4: Error
else
    log_error "Pod URL could not be determined"
    show helpful error message with all options
    exit 1
fi
```

**Auto-detection Function**:
```bash
detect_pod_url_from_runpodctl() {
    # Check if runpodctl is available
    if ! command -v runpodctl &> /dev/null; then
        return 1
    fi

    # Get first RUNNING pod ID
    local pod_id=$(runpodctl get pod 2>/dev/null | grep "RUNNING" | head -1 | awk '{print $1}')

    # Construct proxy URL if pod found
    if [[ -n "$pod_id" ]]; then
        echo "https://${pod_id}-8188.proxy.runpod.net"
        return 0
    fi

    return 1
}
```

---

### HTTP API Interaction

**Endpoint usage**:
```bash
# 1. Connectivity check
GET ${POD_URL}/system_stats
→ {"system": {"os": "Linux"}, "devices": [...]}

# 2. Submit workflow
POST ${POD_URL}/prompt
Body: {"prompt": {...workflow_json...}, "client_id": "uuid"}
→ {"prompt_id": "uuid", "number": 1}

# 3. Poll for completion (every 2 seconds)
GET ${POD_URL}/history/${PROMPT_ID}
→ {"prompt_id": {"outputs": {...}, "status": "completed"}}

# 4. Download images
GET ${POD_URL}/view?filename={FILE}&subfolder={SUB}&type={TYPE}
→ Binary image data (PNG)
```

### Polling Logic

```bash
poll_remote_completion() {
    local POLL_INTERVAL=2
    local MAX_POLLS=$((TIMEOUT_SECONDS / POLL_INTERVAL))
    local POLL_COUNT=0

    while [[ $POLL_COUNT -lt $MAX_POLLS ]]; do
        # Fetch history with timeout
        HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" \
            --connect-timeout 5 \
            "${POD_URL}/history/${PROMPT_ID}")

        HISTORY=$(echo "$HTTP_RESPONSE" | head -n -1)
        STATUS_CODE=$(echo "$HTTP_RESPONSE" | tail -n 1)

        # Check if complete
        if echo "$HISTORY" | jq -e ".\"$PROMPT_ID\".outputs" > /dev/null 2>&1; then
            handle_remote_response "$HISTORY"
            return 0
        fi

        # Progress update every 20 seconds
        if (( POLL_COUNT % 10 == 0 )); then
            log_info "Still processing remotely... (${ELAPSED}s)"
        fi

        sleep $POLL_INTERVAL
        ((POLL_COUNT++))
    done

    log_error "Timeout after ${TIMEOUT_SECONDS}s"
    return 2
}
```

### Image Download Mechanism

```bash
download_remote_images() {
    local outputs_json="$1"

    # Parse outputs JSON with Python
    python3 << 'PYTHON_EOF'
import json
import sys

outputs = json.loads('''OUTPUT_JSON'''.replace('OUTPUT_JSON', sys.stdin.read()))

for node_id, node_output in outputs.items():
    if 'images' in node_output:
        for img in node_output['images']:
            filename = img.get('filename', '')
            subfolder = img.get('subfolder', '')
            img_type = img.get('type', 'output')
            print(f"{filename}|{subfolder}|{img_type}")
PYTHON_EOF

    # Download each image
    while IFS='|' read -r filename subfolder img_type; do
        local url="${POD_URL}/view?filename=${filename}&type=${img_type}"
        [[ -n "$subfolder" ]] && url="${url}&subfolder=${subfolder}"

        local output_path="${LOCAL_OUTPUT_FOLDER}/${filename}"

        log_info "Downloading: $filename"
        if curl -# -f -o "$output_path" \
            --connect-timeout 10 \
            --max-time 300 \
            "$url"; then
            log_success "Downloaded: $output_path"
        else
            log_error "Download failed: $filename"
        fi
    done
}
```

---

### 4. Error Handling Strategy

**Error categories and handling**:

| Error Type | Detection | Handling |
|------------|-----------|----------|
| Pod unreachable | Connection refused | Retry with backoff (5 attempts) |
| Invalid URL | URL parse error | Fail fast with helpful message |
| Workflow validation | Missing nodes | Local validation catches early |
| Execution error | Error in history | Extract and display error |
| Download failure | curl exit code | Retry individual download |
| Timeout | Max polls reached | Save prompt_id for recovery |
| Network interruption | Connection drop | Resume polling if possible |

**Retry pattern with exponential backoff**:
```bash
retry_with_backoff() {
    local max_attempts=5
    local timeout=1

    for attempt in $(seq 1 $max_attempts); do
        if "$@"; then
            return 0
        fi
        log_warn "Attempt $attempt failed, retrying in ${timeout}s..."
        sleep $timeout
        timeout=$((timeout * 2))
    done

    return 1
}
```

---

### 5. Edge Cases to Handle

#### A. URL Format Variations
```bash
# Accept these formats:
https://zu9sxe2gu0lswm-8188.proxy.runpod.net
zu9sxe2gu0lswm-8188.proxy.runpod.net
https://zu9sxe2gu0lswm-8188.proxy.runpod.net/
```

#### B. File Conflicts
```bash
# If local file exists, append timestamp
output_path="${LOCAL_OUTPUT_FOLDER}/${basename}_${START_TIMESTAMP}.${ext}"
```

#### C. Incomplete Downloads
```bash
# Verify file size > 0 and PNG signature
verify_download() {
    [[ -s "$filepath" ]] || return 1
    local header=$(xxd -l 4 -p "$filepath")
    [[ "$header" == "89504e47" ]] || log_warn "May not be valid PNG"
}
```

#### D. Pod Stopped Mid-Execution
```bash
# Save prompt_id for recovery
log_error "Lost connection to pod"
log_info "Prompt ID: $PROMPT_ID (save this for later recovery)"
```

---

### 6. Testing Approach

#### Phase 1: Unit Tests
```bash
# Test connectivity
./comfy-run-remote.sh --pod-url https://zu9sxe2gu0lswm-8188.proxy.runpod.net --help

# Test workflow validation (no submission)
DEBUG=1 ./comfy-run-remote.sh \
    --pod-url https://zu9sxe2gu0lswm-8188.proxy.runpod.net \
    --prompt "test" \
    --no-download
```

#### Phase 2: Integration Tests
```bash
# Full execution with download
./comfy-run-remote.sh \
    --pod-url https://zu9sxe2gu0lswm-8188.proxy.runpod.net \
    --prompt "A red car" \
    --image-id "test_001" \
    --seed 42 \
    --local-output ./test_output/

# Verify output
ls -lh ./test_output/
```

#### Phase 3: Error Handling Tests
```bash
# Pod unreachable
./comfy-run-remote.sh --pod-url https://invalid:8188.proxy.runpod.net --prompt "test"

# Timeout
./comfy-run-remote.sh --pod-url https://zu9sxe2gu0lswm-8188.proxy.runpod.net \
    --prompt "test" --timeout 5
```

#### Phase 4: Regression Tests
```bash
# Compare local vs remote (same seed)
./comfy-run.sh --prompt "A red car" --seed 12345
./comfy-run-remote.sh --pod-url https://zu9sxe2gu0lswm-8188.proxy.runpod.net \
    --prompt "A red car" --seed 12345
# Images should be identical with same seed
```

---

### 7. Function Dependency Map

```
main()
├── parse_arguments()
├── validate_arguments()
│   └── validate_workflow_structure() [reuse]
├── detect_pod_url()
│   ├── normalize_pod_url()
│   └── check_remote_connectivity()
├── verify_dependencies() [reuse]
├── init_generation_log() [modified]
├── process_workflow_template() [reuse]
├── convert_ui_to_api_format() [reuse]
├── substitute_seed() [reuse]
├── submit_remote_workflow() [new]
│   └── retry_with_backoff()
├── poll_remote_completion() [new]
│   └── handle_remote_response() [new]
├── download_remote_images() [new]
│   ├── parse_outputs_json()
│   ├── download_single_image()
│   └── verify_download()
└── finalize_generation_log() [modified]
```

**Reused functions (from comfy-run.sh):** ~60%
**New functions (remote-specific):** ~40%

---

## Implementation Checklist

### Core Functionality
- [ ] Argument parsing (--pod-url, --local-output, etc.)
- [ ] Pod URL detection and validation
- [ ] Remote connectivity check
- [ ] Workflow processing (reuse from comfy-run.sh)
- [ ] Remote workflow submission (POST /prompt)
- [ ] Progress polling (GET /history/{prompt_id})
- [ ] Image metadata extraction
- [ ] Image download (GET /view)
- [ ] Download verification

### Error Handling
- [ ] Network retry with exponential backoff
- [ ] Pod unreachable detection
- [ ] Workflow validation errors
- [ ] Execution error extraction
- [ ] Download failure recovery
- [ ] Timeout handling
- [ ] Connection drop detection

### Logging
- [ ] Local log directory creation
- [ ] Generation log initialization
- [ ] Network timing metrics
- [ ] Download progress tracking
- [ ] Error context logging
- [ ] Log finalization

### Testing
- [ ] Unit tests (connectivity, validation)
- [ ] Integration tests (full workflow)
- [ ] Error handling tests
- [ ] Regression tests (compare with local)
- [ ] Edge case tests (URL formats, conflicts)

### Documentation
- [ ] Help text with remote examples
- [ ] Parameter descriptions
- [ ] Error messages with guidance
- [ ] Usage examples in comments

---

## Success Criteria

### Functional Requirements
1. ✅ Submit workflows to remote RunPod instance
2. ✅ Monitor execution progress in real-time
3. ✅ Download generated images to localhost
4. ✅ Handle all error conditions gracefully
5. ✅ Match output quality of local comfy-run.sh

### Non-Functional Requirements
1. ✅ Reuse 60%+ of existing code
2. ✅ No new dependencies (curl, jq, python3 only)
3. ✅ Execution time: <5s overhead vs local
4. ✅ Memory usage: <100MB
5. ✅ Clear error messages for common issues

### Verification Steps
1. Run workflow remotely and download images
2. Compare output with local execution (same seed)
3. Test all error conditions
4. Verify logs are comprehensive
5. Check performance metrics

---

## Critical URL Format (Tested & Confirmed)

### ✅ CORRECT: RunPod Proxy URL
```bash
https://{POD_ID}-8188.proxy.runpod.net

# Example:
https://zu9sxe2gu0lswm-8188.proxy.runpod.net

# Get current pod ID:
runpodctl pod list
```

### ❌ DOES NOT WORK: Direct IP (Blocked by RunPod)
```bash
http://104.255.9.187:8188  # ← This is blocked
```

### ⚠️ IMPORTANT: Pod ID Changes Daily
- Pod ID changes each time the pod is restarted
- Always get fresh pod ID from: `runpodctl pod list`
- Update proxy URL each time you restart the pod

---

## Estimated Effort

- **Implementation**: 1,100 lines of code
  - Reused: ~650 lines (60%)
  - New: ~450 lines (40%)
- **Testing**: 5-8 hours
- **Documentation**: Included in code
- **Total**: 1-2 days for complete implementation and testing

---

## Next Steps

1. **Review**: Read through this entire plan
2. **Reference**: Keep TEST_VALUES.md and QUICK_REFERENCE.txt nearby
3. **Code**: Start implementing following the structure above
4. **Test**: Run test suite to validate implementation
5. **Deploy**: Commit and push to repository

---

**Created**: 2026-01-31
**Version**: 1.0 - Complete Implementation Plan
**Ready for**: Phase 2 Implementation
