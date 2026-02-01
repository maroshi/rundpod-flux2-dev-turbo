# Test Values and Configuration for comfy-run-remote.sh Tests

This document provides all the test values and configurations used in the test scripts.

## Pod Configuration

### Pod Details
```bash
POD_ID=zu9sxe2gu0lswm
POD_NAME=ghcr.io/maroshi/flux2-dev-turbo:latest
POD_HTTP_PORT=8188
POD_SSH_PORT=11597
POD_STATUS=RUNNING
GPU=1 A100 PCIe 80GB
```

### Connection Strings (CORRECTED - Use RunPod Proxy)
```bash
# ✅ CORRECT: Use RunPod Proxy URL (pod ID changes daily!)
# Get current pod ID: runpodctl pod list
POD_ID="<get-from-runpodctl-pod-list>"  # Changes daily!
POD_URL="https://${POD_ID}-8188.proxy.runpod.net"

# ❌ DOES NOT WORK: Direct IP is blocked by RunPod
# POD_URL="http://104.255.9.187:8188"  # ← This is blocked

# SSH Connection (for file transfer if needed)
SSH_CONNECTION="root@<pod-ip>:11597"

# Environment Variables (Set before running)
export RUNPOD_POD_ID="<get-from-runpodctl>"  # Required! Changes daily
export RUNPOD_POD_URL="https://${RUNPOD_POD_ID}-8188.proxy.runpod.net"
```

### Getting Your Pod ID
```bash
# List all pods (shows current pod IDs)
runpodctl pod list

# The output shows your pod ID, example:
# zu9sxe2gu0lswm  ghcr.io/maroshi/flux2-dev-turbo  RUNNING  A100

# Use that ID in the proxy URL
export RUNPOD_POD_ID="zu9sxe2gu0lswm"
export RUNPOD_POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"
```

### URL Format Explanation
```bash
# RunPod Proxy URL Format (POD_ID changes daily!):
https://{POD_ID}-{PORT}.proxy.runpod.net

# Example with today's pod ID:
https://zu9sxe2gu0lswm-8188.proxy.runpod.net
      └─ POD_ID (changes daily) ─┘ └ PORT (8188) ┘

# IMPORTANT: Get current POD_ID from: runpodctl pod list

# Endpoints (same for all pod IDs):
/prompt  - Submit workflows
/queue   - Check queue status
/history/{prompt_id} - Get results
/view?filename=... - Download images
```

---

## Test Prompts and Parameters

### Basic Test Prompts
```bash
# Simple test
PROMPT_1="A red car"

# Descriptive test
PROMPT_2="A beautiful sunset over mountains with golden light"

# Complex test
PROMPT_3="High quality professional photography of a modern minimalist house, 4K, cinematic lighting, architectural digest style"
```

### Test Seeds
```bash
# Reproducible generation
SEED_1=42
SEED_2=12345
SEED_3=999

# Auto-generated (if not specified)
# Pattern: random int + epoch time
```

### Test Image IDs
```bash
IMAGE_ID_1="test_001"
IMAGE_ID_2="batch_001_001"
IMAGE_ID_3="debug_minimal"
IMAGE_ID_4="integration_full"
```

### Test Workflows
```bash
# Fast 512x512 (default)
WORKFLOW_1="flux2_turbo_512x512_parametric_api.json"

# High quality 1024x1024
WORKFLOW_2="flux2_turbo_default_api.json"

# Variable steps
WORKFLOW_3="flux2_turbo_2-8steps_sharcodin.json"

# With reference images
WORKFLOW_4="flux2_turbo_kombitz_6ref.json"
```

---

## Mock API Responses

### Successful Workflow Submission
```json
{
  "prompt_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "number": 1
}
```

### Queue Status Response
```json
{
  "queue_pending": [
    [1, {"prompt": "...", "client_id": "..."}],
    [2, {"prompt": "...", "client_id": "..."}]
  ],
  "queue_running": [
    [0, {"prompt": "...", "client_id": "..."}]
  ]
}
```

### System Stats Response
```json
{
  "system": "Linux",
  "python_version": "3.10.0",
  "os_name": "posix",
  "devices": [
    {
      "name": "cuda:0",
      "type": "GPU",
      "vram_total": 81920,
      "vram_free": 40960
    }
  ]
}
```

### Workflow Completed (History Response)
```json
{
  "a1b2c3d4-e5f6-7890-abcd-ef1234567890": {
    "prompt": [...],
    "outputs": {
      "9": {
        "images": [
          {
            "filename": "ComfyUI_00001_.png",
            "subfolder": "output",
            "type": "output"
          }
        ]
      }
    },
    "status": {
      "status_str": "success"
    }
  }
}
```

### Workflow Error Response
```json
{
  "errors": [
    "Workflow validation failed: missing required input"
  ],
  "node_errors": {
    "1": ["CheckpointLoader: Model file not found"],
    "3": ["KSampler: Invalid seed value"]
  }
}
```

### History Not Found (Non-existent Prompt)
```json
{}
```

---

## Test Scenarios

### Scenario 1: Basic End-to-End Test
```bash
#!/bin/bash
# Get current pod ID (changes daily!)
POD_ID=$(runpodctl pod list | grep "RUNNING" | awk '{print $1}' | head -1)
POD_URL="https://${POD_ID}-8188.proxy.runpod.net"

./comfy-run-remote.sh \
  --pod-url "$POD_URL" \
  --prompt "A red car" \
  --image-id "test_001" \
  --seed 42 \
  --workflow "flux2_turbo_512x512_parametric_api.json" \
  --local-output "./test_output/"
```

Or manually set pod ID:
```bash
POD_ID="zu9sxe2gu0lswm"  # Get from: runpodctl pod list
POD_URL="https://${POD_ID}-8188.proxy.runpod.net"

./comfy-run-remote.sh --pod-url "$POD_URL" --prompt "A red car"
```

Expected result:
- Image generated and downloaded to `./test_output/`
- Log created at `./logs/generations/generation_*.log`
- Exit code: 0

---

### Scenario 2: Pod Unreachable (Error Handling)
```bash
#!/bin/bash
POD_URL="https://invalid-pod-id-8188.proxy.runpod.net"

./comfy-run-remote.sh \
  --pod-url "$POD_URL" \
  --prompt "test"
```

Expected result:
- Script attempts 5 retries with exponential backoff
- Clear error message: "Pod is not accessible"
- Exit code: 1
- Log indicates connection attempts

---

### Scenario 3: Invalid Workflow (Validation Error)
```bash
#!/bin/bash
POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"

./comfy-run-remote.sh \
  --pod-url "$POD_URL" \
  --prompt "test" \
  --workflow "nonexistent.json"
```

Expected result:
- Local validation catches missing file
- Error message: "Workflow file not found"
- Exit code: 1
- No network request made

---

### Scenario 4: Execution Timeout (Long Wait)
```bash
#!/bin/bash
POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"

./comfy-run-remote.sh \
  --pod-url "$POD_URL" \
  --prompt "test" \
  --timeout 10  # Very short timeout
```

Expected result:
- Polls for 10 seconds (~5 checks at 2s intervals)
- Timeout error: "Workflow exceeded timeout"
- Saves prompt_id for manual recovery
- Exit code: 2

---

### Scenario 5: Custom Output Paths
```bash
#!/bin/bash
POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"

./comfy-run-remote.sh \
  --pod-url "$POD_URL" \
  --prompt "A beautiful landscape" \
  --image-id "landscape_001" \
  --local-output "/tmp/ai-images/" \
  --output-folder "/workspace/remote-output/"
```

Expected behavior:
- Workflow generates images in remote `/workspace/remote-output/`
- Images downloaded to local `/tmp/ai-images/`
- Logs stored in `./logs/generations/`

---

### Scenario 6: SSH Connection Parameter
```bash
#!/bin/bash
SSH_CONN="root@104.255.9.187:11597"

./comfy-run-remote.sh \
  --ssh-connection "$SSH_CONN" \
  --prompt "test"
```

Expected behavior:
- Script converts SSH connection to HTTP URL
- Extracts host: 104.255.9.187
- Constructs: http://104.255.9.187:8188
- Proceeds with normal execution

---

### Scenario 7: Batch Processing
```bash
#!/bin/bash
POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"

for i in {1..5}; do
  ./comfy-run-remote.sh \
    --pod-url "$POD_URL" \
    --prompt "Image $i" \
    --image-id "batch_001_$(printf '%03d' $i)" \
    --local-output "./batch_output/"
done
```

Expected behavior:
- 5 sequential submissions
- Each has unique prompt_id
- Images numbered 001-005
- All logs in `./logs/generations/`

---

### Scenario 8: No Download Mode (Testing Only)
```bash
#!/bin/bash
POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"

./comfy-run-remote.sh \
  --pod-url "$POD_URL" \
  --prompt "test" \
  --no-download  # Skip image download
```

Expected behavior:
- Submits workflow and polls for completion
- Does NOT download images
- Useful for testing API interaction without storage
- Exit code: 0 if successful

---

### Scenario 9: Execution Error Handling (Enhanced)
```bash
#!/bin/bash
POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"

# Submit workflow with missing model file (intentional error)
./comfy-run-remote.sh \
  --pod-url "$POD_URL" \
  --prompt "test" \
  --workflow "broken_workflow.json"
```

Expected behavior:
- Workflow submitted successfully
- Poll detects error status
- Script extracts and displays error details:
  - Status message
  - Node-level errors
  - Full error context
- Log file contains full error stack
- Exit code: 1
- Log shows: "WORKFLOW EXECUTION ERROR" section with details

---

### Scenario 10: Download Retry on Failure (Enhanced)
```bash
#!/bin/bash
POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"

# Simulate flaky network during download
DEBUG=1 ./comfy-run-remote.sh \
  --pod-url "$POD_URL" \
  --prompt "test" \
  --local-output "./retry_test/"
```

Expected behavior:
- If download fails (network error):
  - Retry attempt 1 (after 1s)
  - Retry attempt 2 (after 2s)
  - Retry attempt 3 (final)
- If PNG verification fails (incomplete):
  - Delete incomplete file
  - Retry with backoff
- Log shows: "Retrying download (attempt N/3)"
- If all retries fail: error logged, other images still downloaded
- Exit code: 0 if at least one image downloaded

---

### Scenario 11: File Conflict Resolution (Enhanced)
```bash
#!/bin/bash
POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"

# First run
./comfy-run-remote.sh \
  --pod-url "$POD_URL" \
  --prompt "test" \
  --image-id "test_001" \
  --local-output "./conflict_test/"

# Second run (same settings, will produce same filename)
./comfy-run-remote.sh \
  --pod-url "$POD_URL" \
  --prompt "test" \
  --image-id "test_001" \
  --local-output "./conflict_test/"
```

Expected behavior:
- First run: Downloads `ComfyUI_00001.png`
- Second run: Detects file exists
- Renames second to: `ComfyUI_00001_1.png`
- Both files preserved (no overwrite)
- Log shows: "File conflict resolved: renamed to ComfyUI_00001_1.png"
- Exit code: 0

---

### Scenario 12: Timeout and Recovery (Enhanced)
```bash
#!/bin/bash
POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"

# Use very short timeout to trigger
./comfy-run-remote.sh \
  --pod-url "$POD_URL" \
  --prompt "A complex image with many details" \
  --image-id "timeout_test" \
  --timeout 10  # 10 seconds (will likely timeout)
```

Expected behavior:
- Workflow submitted successfully
- Polling starts for 10 seconds
- Timeout reached
- Recovery file created: `./logs/recovery/prompt_YYYYMMDD_HHMMSS.recovery`
- Recovery file contains:
  - PROMPT_ID (for later status check)
  - POD_URL
  - IMAGE_ID, SEED, LOCAL_OUTPUT_FOLDER
  - Instructions for manual status check
- Console displays:
  - "WORKFLOW TIMEOUT - RECOVERY INFORMATION"
  - Prompt ID and pod URL
  - Commands to check status
  - Recovery file location
- Exit code: 2

### How to Use Recovery File
```bash
# After workflow times out, recovery file is at:
cat ./logs/recovery/prompt_YYYYMMDD_HHMMSS.recovery

# Source it to get variables
source ./logs/recovery/prompt_YYYYMMDD_HHMMSS.recovery

# Check if workflow is done:
curl -s "$POD_URL/history/$PROMPT_ID" | jq ".\"$PROMPT_ID\".outputs"

# If complete, download images manually
```

---

### Scenario 13: Error Extraction Details (Enhanced)
```bash
POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"

# Check what error information is extracted
PROMPT_ID="abc123def456"

# Get full history response
curl -s "$POD_URL/history/$PROMPT_ID" | jq .

# Extract error status
curl -s "$POD_URL/history/$PROMPT_ID" | jq ".\"$PROMPT_ID\".status"

# Extract node errors
curl -s "$POD_URL/history/$PROMPT_ID" | jq ".\"$PROMPT_ID\".status.nodes"

# Extract messages
curl -s "$POD_URL/history/$PROMPT_ID" | jq ".\"$PROMPT_ID\".status.messages"
```

Expected response format:
```json
{
  "status": {
    "status_str": "error",
    "messages": ["Error message 1", "Error message 2"],
    "nodes": {
      "1": "CheckpointLoader: Model not found",
      "3": "KSampler: Invalid seed value"
    }
  }
}
```

---

## Test File Locations

```
rundpod-flux2-dev-turbo/workflows/
├── comfy-run-remote.sh              # Main script (to be created)
├── test-remote-runner.sh            # Comprehensive test suite
├── test-pod-connectivity.sh         # Connectivity & diagnostics
├── test-workflow-api.sh             # API interaction tests
├── TEST_VALUES.md                   # This file
├── test-output/                     # Generated during tests
│   ├── api-tests/
│   │   ├── system_stats.json
│   │   ├── queue_status.json
│   │   ├── workflow_response.json
│   │   ├── workflow_result.json
│   │   └── history.json
│   ├── images/
│   │   └── test_*.png
│   └── logs/
│       └── test_generation_*.log
└── logs/generations/                # Runtime logs
    └── generation_*.log
```

---

## Running the Tests

### Test 1: Full Test Suite
```bash
cd rundpod-flux2-dev-turbo/workflows/

# Run all tests
bash test-remote-runner.sh

# View results
cat test-results.log
```

### Test 2: Connectivity Tests Only
```bash
bash test-pod-connectivity.sh
```

Expected output:
- HTTP connectivity checks
- SSH connection tests
- Performance metrics
- Diagnostic information

### Test 3: API Tests Only
```bash
bash test-workflow-api.sh
```

Expected output:
- Pod information
- Queue status
- Response parsing validation
- JSON workflow tests

### Test 4: Actual Remote Execution (When Script is Ready)
```bash
# Basic test
./comfy-run-remote.sh \
  --prompt "A red car" \
  --seed 42 \
  --image-id "manual_test_001"

# With custom output
./comfy-run-remote.sh \
  --prompt "A beautiful landscape" \
  --local-output "./my_images/" \
  --image-id "landscape_001" \
  --seed 12345
```

---

## Environment Variables for Testing

```bash
# Pod configuration
export RUNPOD_POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"
export RUNPOD_SSH_CONNECTION="root@104.255.9.187:11597"
export RUNPOD_POD_ID="zu9sxe2gu0lswm"

# Test options
export DEBUG=1                        # Enable debug output
export TIMEOUT=3600                   # Max execution time (seconds)
export POLL_INTERVAL=2               # Polling interval (seconds)

# Optional
export SKIP_DOWNLOAD=1               # Don't download images
export KEEP_LOGS=1                   # Keep all log files
```

---

## Debugging Commands

### Check Pod Status
```bash
POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"

# System info
curl -s "$POD_URL/system_stats" | jq .

# Queue status
curl -s "$POD_URL/queue" | jq .

# History for specific prompt
curl -s "$POD_URL/history/{prompt_id}" | jq .
```

### View Test Results
```bash
# Check test log
cat test-results.log | grep -E "PASS|FAIL"

# View API responses
cat test-output/api-tests/*.json | jq .

# Check generation logs
ls -la logs/generations/
```

### Manual Image Download
```bash
# Download an image
POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"
curl -o "image.png" \
  "$POD_URL/view?filename=ComfyUI_00001_.png&subfolder=output&type=output"
```

---

## Performance Benchmarks

Expected performance characteristics:

| Operation | Time | Notes |
|-----------|------|-------|
| Pod connectivity check | 100-200ms | /system_stats |
| Workflow submission | 200-500ms | POST /prompt |
| Single polling check | 50-100ms | GET /history |
| Image download (1MB) | 1-2 seconds | Network dependent |
| Full workflow cycle | 30-60 seconds | Including 5-20s model load |

---

## Success Criteria Checklist

- [ ] Test scripts run without errors
- [ ] Connectivity tests detect pod status correctly
- [ ] API tests validate JSON responses
- [ ] Parameter parsing works correctly
- [ ] Error handling tests show proper error messages
- [ ] Full integration test downloads images successfully
- [ ] Logs are generated with correct format
- [ ] Performance is acceptable (<5s overhead vs local)

---

## Troubleshooting

### Pod Unreachable
- Check pod is running: `runpodctl pod list`
- Verify URL format: `http://IP:8188` (not localhost)
- Check network connectivity: `ping POD_IP`

### Slow Response
- Check pod CPU/GPU load: `/system_stats`
- Verify network latency: `curl -w "Time: %{time_total}s" $POD_URL/queue`
- Check queue length: `curl $POD_URL/queue | jq '.queue_pending | length'`

### Test Failures
- Enable debug: `DEBUG=1 ./test-script.sh`
- Check logs: `tail -f test-results.log`
- Review error responses: `cat test-output/api-tests/*.json`

