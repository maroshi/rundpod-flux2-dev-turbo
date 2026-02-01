# Running Tests for comfy-run-remote.sh

Quick start guide for running all test scripts.

## Prerequisites

Make sure you have the following installed:
- bash
- curl
- jq
- python3
- ssh (for SSH connectivity tests)

## Test Scripts Overview

| Script | Purpose | Duration | Requires Pod |
|--------|---------|----------|--------------|
| `test-remote-runner.sh` | Unit tests (help, validation, connectivity) | 5-10 min | Optional |
| `test-pod-connectivity.sh` | Pod connectivity & diagnostics | 2-3 min | Yes |
| `test-workflow-api.sh` | API interaction testing | 3-5 min | Yes |
| `test-integration.sh` | **[NEW] Phase 2: Full workflow execution & download** | 10-15 min | Yes |
| `test-error-handling.sh` | **[NEW] Phase 3: Error detection & recovery** | 5-10 min | Yes |
| `test-regression.sh` | **[NEW] Phase 4: Local vs remote equivalence** | 20-30 min | Yes |

## Quick Start

### 1. Run Unit Tests (No Pod Required)
```bash
cd rundpod-flux2-dev-turbo/workflows/

# Make scripts executable
chmod +x test-*.sh comfy-run-remote.sh

# Run help, validation, and dependency tests
bash test-remote-runner.sh

# View results
cat test-results.log
```

### 2. Run Connectivity Tests (Requires Pod)
```bash
export RUNPOD_POD_URL="https://YOUR_POD_ID-8188.proxy.runpod.net"
bash test-pod-connectivity.sh
```

This will:
- Check pod accessibility at configured URL
- Test HTTP endpoints
- Test SSH connectivity
- Verify dependencies
- Show system diagnostics

### 3. Run API Tests (Requires Pod)
```bash
bash test-workflow-api.sh
```

This will:
- Verify pod is accessible
- Fetch pod information
- Test API response parsing
- Validate workflow JSON
- Run stress tests

### 4. Run Full Test Suite (All Phases - Requires Pod)
```bash
# Phase 1: Unit Tests (no pod)
bash test-remote-runner.sh

# Phase 2: Integration Tests (requires pod)
bash test-integration.sh

# Phase 3: Error Handling Tests (requires pod)
bash test-error-handling.sh

# Phase 4: Regression Tests (requires pod + comfy-run.sh)
bash test-regression.sh
```

### 5. Run Specific Test Suite
```bash
# Only help and validation tests
bash test-remote-runner.sh --suite test_help_and_validation

# Only dependency tests
bash test-remote-runner.sh --suite test_dependencies
```

## Test Configuration

### Set Pod URL (Changes Daily!)
```bash
# Step 1: Get current pod ID
runpodctl pod list
# Output shows pod ID, e.g.: zu9sxe2gu0lswm

# Step 2: Set environment variable with RunPod proxy URL
export RUNPOD_POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"
# Replace 'zu9sxe2gu0lswm' with your actual pod ID from step 1

# Step 3: Run tests
bash test-pod-connectivity.sh
```

### URL Format (Pod ID Changes Daily)
```bash
# RunPod proxy URL format:
https://{POD_ID}-8188.proxy.runpod.net

# Get POD_ID from: runpodctl pod list
# Do this EVERY TIME you restart your pod
```

### Set SSH Connection
```bash
# Get pod IP first
runpodctl pod list  # Shows IP address

export RUNPOD_SSH_CONNECTION="root@<pod-ip>:11597"
bash test-pod-connectivity.sh
```

### Enable Debug Output
```bash
DEBUG=1 bash test-remote-runner.sh
```

## Expected Output

### Successful Test Run
```
╔════════════════════════════════════════════════════════════════╗
║       comfy-run-remote.sh Test Suite                          ║
╚════════════════════════════════════════════════════════════════╝

[INFO] Test output directory: ./test-output
[INFO] Pod URL: http://104.255.9.187:8188
[INFO] Remote script: ./comfy-run-remote.sh

════════════════════════════════════════════════════════════════
  SETUP
════════════════════════════════════════════════════════════════
[TEST] Test output directory: ./test-output
[PASS] Remote script found

════════════════════════════════════════════════════════════════
  TEST SUITE 1: Help and Validation
════════════════════════════════════════════════════════════════
[TEST] Test 1.1: Display help message
[PASS] Help command executed successfully
[PASS] Help contains script description

...

════════════════════════════════════════════════════════════════
  TEARDOWN
════════════════════════════════════════════════════════════════
[TEST] Test results:
[TEST]   PASSED: 45
[TEST]   FAILED: 0
[TEST]   SKIPPED: 2
[PASS] All tests passed!

Full test log: ./test-results.log
```

## Test Results Files

After running tests, check these files:

```bash
# Main test log
cat test-results.log

# API test responses
ls -la test-output/api-tests/
cat test-output/api-tests/system_stats.json | jq .

# Generation logs
ls -la logs/generations/
```

## Interpreting Test Results

### Color Codes
- 🟢 **GREEN [PASS]** - Test passed
- 🔴 **RED [FAIL]** - Test failed (needs investigation)
- 🟡 **YELLOW [SKIP]** - Test skipped (usually pod not accessible)
- 🔵 **BLUE [TEST] [INFO]** - Test information

### Common Issues

#### "Pod is not accessible"
```bash
# Check if pod URL is correct
echo $RUNPOD_POD_URL

# Test connectivity manually
curl -v http://104.255.9.187:8188/system_stats

# Check pod status
runpodctl pod list
```

#### "Failed to fetch pod info"
```bash
# Verify pod is running
runpodctl pod status zu9sxe2gu0lswm

# Check ComfyUI is started
curl http://104.255.9.187:8188/queue
```

#### "Remote script not found"
```bash
# Create the script (to be done)
touch comfy-run-remote.sh
chmod +x comfy-run-remote.sh

# Or download from git
git pull origin main
```

## Test Coverage

### Currently Tested
- ✅ Script help and validation
- ✅ Parameter parsing
- ✅ Workflow file validation
- ✅ Pod connectivity
- ✅ HTTP endpoints
- ✅ JSON parsing
- ✅ Error handling
- ✅ Logging functionality
- ✅ Network timeouts
- ✅ Dependencies verification
- ✅ **[NEW] Execution error extraction** - Errors from pod responses
- ✅ **[NEW] Download retry logic** - 3 retries with backoff
- ✅ **[NEW] File conflict resolution** - Automatic renaming for duplicates
- ✅ **[NEW] Recovery mechanism** - Saved prompt_id files for timeout recovery

### To Be Tested (After Script Implementation)
- ⏳ Actual workflow submission
- ⏳ Remote execution and polling
- ⏳ Image download with retry
- ⏳ Error extraction and display
- ⏳ Recovery file creation
- ⏳ Full end-to-end workflow

## Phase 2: Integration Tests

Run full workflow execution with image downloads to verify end-to-end functionality.

### Prerequisites
- Pod URL must be configured and running
- ComfyUI must be accessible
- Default workflow must exist

### Running Phase 2 Tests
```bash
cd rundpod-flux2-dev-turbo/workflows/
bash test-integration.sh
```

### Test 2.1: Full Workflow Execution
```bash
./comfy-run-remote.sh \
    --pod-url "https://zu9sxe2gu0lswm-8188.proxy.runpod.net" \
    --prompt "A red car on a sunny street" \
    --image-id "integration_001" \
    --seed 42 \
    --local-output ./test_output/

# Verify output
ls -lh ./test_output/
```

**Expected Results:**
- ✅ Script exits with code 0
- ✅ Images downloaded to `./test_output/`
- ✅ At least one PNG file created
- ✅ File size > 50KB
- ✅ Log file created in `./logs/generations/`

### Test 2.2: Multiple Concurrent Submissions
```bash
for i in {1..3}; do
    ./comfy-run-remote.sh \
        --pod-url "https://zu9sxe2gu0lswm-8188.proxy.runpod.net" \
        --prompt "Test image $i" \
        --image-id "concurrent_$i" \
        --seed $((1000 + i)) \
        --local-output ./test_output/ &
done
wait

# Verify all outputs
ls -lh ./test_output/ | wc -l
```

**Expected Results:**
- ✅ All 3 submissions complete successfully
- ✅ 3+ image files in output directory
- ✅ No file conflicts or overwrites
- ✅ Each with unique metadata

### Test 2.3: Download Verification
```bash
./comfy-run-remote.sh \
    --pod-url "https://zu9sxe2gu0lswm-8188.proxy.runpod.net" \
    --prompt "Download verification test" \
    --image-id "verify_001" \
    --local-output ./test_output/

# Verify file integrity
for img in ./test_output/*.png; do
    file "$img"  # Check file type
    stat "$img"  # Check size
done
```

**Expected Results:**
- ✅ All files identified as PNG
- ✅ All files > 50KB
- ✅ Valid PNG magic bytes (89 50 4E 47)

### Test 2.4: Progress Polling Verification
```bash
DEBUG=1 ./comfy-run-remote.sh \
    --pod-url "https://zu9sxe2gu0lswm-8188.proxy.runpod.net" \
    --prompt "Progress test" \
    --image-id "progress_001" \
    --local-output ./test_output/ 2>&1 | tee polling_test.log

# Check polling output
grep "Still processing" polling_test.log
grep "poll" polling_test.log
```

**Expected Results:**
- ✅ "Still processing" messages appear
- ✅ Progress updates every ~20 seconds
- ✅ Poll interval is consistent (2s)

---

## Phase 4: Regression Tests

Verify that remote execution produces identical results to local execution (with same seed).

### Prerequisites
- Both `comfy-run.sh` and `comfy-run-remote.sh` must be available
- Pod must be running
- Enough disk space for output comparison

### Running Phase 4 Tests
```bash
cd rundpod-flux2-dev-turbo/workflows/
bash test-regression.sh
```

### Test 4.1: Seed Reproducibility (Local)
```bash
# First run
./comfy-run.sh \
    --prompt "A red car" \
    --seed 12345 \
    --output-folder ./regression_local_1/

# Second run with same seed
./comfy-run.sh \
    --prompt "A red car" \
    --seed 12345 \
    --output-folder ./regression_local_2/

# Compare
diff <(md5sum ./regression_local_1/*.png | sort) \
     <(md5sum ./regression_local_2/*.png | sort)
```

**Expected Results:**
- ✅ MD5 hashes match exactly
- ✅ Image files are byte-for-byte identical
- ✅ Local execution is deterministic

### Test 4.2: Seed Reproducibility (Remote)
```bash
# First run
./comfy-run-remote.sh \
    --pod-url "https://zu9sxe2gu0lswm-8188.proxy.runpod.net" \
    --prompt "A red car" \
    --seed 12345 \
    --local-output ./regression_remote_1/

# Second run with same seed
./comfy-run-remote.sh \
    --pod-url "https://zu9sxe2gu0lswm-8188.proxy.runpod.net" \
    --prompt "A red car" \
    --seed 12345 \
    --local-output ./regression_remote_2/

# Compare
diff <(md5sum ./regression_remote_1/*.png | sort) \
     <(md5sum ./regression_remote_2/*.png | sort)
```

**Expected Results:**
- ✅ MD5 hashes match exactly
- ✅ Image files are byte-for-byte identical
- ✅ Remote execution is deterministic

### Test 4.3: Local vs Remote Equivalence
```bash
# Generate locally
./comfy-run.sh \
    --prompt "A red car" \
    --seed 12345 \
    --output-folder ./regression_local/

# Generate remotely
./comfy-run-remote.sh \
    --pod-url "https://zu9sxe2gu0lswm-8188.proxy.runpod.net" \
    --prompt "A red car" \
    --seed 12345 \
    --local-output ./regression_remote/

# Compare hashes
echo "Local hashes:"
md5sum ./regression_local/*.png

echo "Remote hashes:"
md5sum ./regression_remote/*.png

# Check if they match
diff <(md5sum ./regression_local/*.png | sort) \
     <(md5sum ./regression_remote/*.png | sort)
```

**Expected Results:**
- ✅ All MD5 hashes match
- ✅ Files are identical byte-for-byte
- ✅ Same number of images generated
- ✅ No quality loss in transfer

### Test 4.4: Different Seeds Produce Different Output
```bash
./comfy-run-remote.sh \
    --pod-url "https://zu9sxe2gu0lswm-8188.proxy.runpod.net" \
    --prompt "A red car" \
    --seed 111 \
    --local-output ./regression_seed_111/

./comfy-run-remote.sh \
    --pod-url "https://zu9sxe2gu0lswm-8188.proxy.runpod.net" \
    --prompt "A red car" \
    --seed 222 \
    --local-output ./regression_seed_222/

# Compare
md5sum ./regression_seed_111/*.png
md5sum ./regression_seed_222/*.png
```

**Expected Results:**
- ✅ MD5 hashes are different
- ✅ Visual output is different
- ✅ Each seed produces unique images

## Performance Testing

### Quick Performance Check
```bash
#!/bin/bash
POD_URL="http://104.255.9.187:8188"

echo "Testing response times..."

# System stats
time curl -s "$POD_URL/system_stats" | jq . > /dev/null

# Queue status
time curl -s "$POD_URL/queue" | jq . > /dev/null

# Non-existent history
time curl -s "$POD_URL/history/fake" | jq . > /dev/null
```

Expected: Each request <500ms

## Continuous Testing

### Watch Test Results
```bash
watch -n 5 'tail test-results.log'
```

### Run Tests on Schedule (cron)
```bash
# Run tests every hour
0 * * * * cd /path/to/workflows && bash test-remote-runner.sh >> cron-test.log 2>&1
```

### Automated Testing in CI/CD
```bash
#!/bin/bash
# In your CI pipeline

cd rundpod-flux2-dev-turbo/workflows/

# Run all tests
bash test-remote-runner.sh

# Check results
if [[ $? -ne 0 ]]; then
    echo "Tests failed!"
    exit 1
fi

echo "All tests passed!"
```

## Phase 3: Error Handling Tests

Test error detection, reporting, and recovery mechanisms.

### Prerequisites
- Pod must be running
- Network connectivity issues can be simulated with iptables (optional)

### Running Phase 3 Tests
```bash
cd rundpod-flux2-dev-turbo/workflows/
bash test-error-handling.sh
```

### Test 3.1: Pod Unreachable Error
```bash
./comfy-run-remote.sh \
    --pod-url "https://invalid-pod-id-8188.proxy.runpod.net" \
    --prompt "Test" \
    --local-output ./test_output/
```

**Expected Results:**
- ✅ Script exits with non-zero code (error)
- ✅ Error message mentions "Pod unreachable" or "connection refused"
- ✅ Helpful guidance provided for troubleshooting
- ✅ Suggests checking pod URL with `runpodctl pod list`

### Test 3.2: Timeout Handling
```bash
./comfy-run-remote.sh \
    --pod-url "https://zu9sxe2gu0lswm-8188.proxy.runpod.net" \
    --prompt "Test" \
    --timeout 5 \
    --local-output ./test_output/
```

**Expected Results:**
- ✅ Script times out after ~5 seconds
- ✅ Error message mentions "Timeout after Xs"
- ✅ Recovery file created in `./logs/recovery/`
- ✅ Prompt ID saved for recovery
- ✅ Instructions provided for checking status

### Test 3.3: Invalid Workflow File
```bash
./comfy-run-remote.sh \
    --pod-url "https://zu9sxe2gu0lswm-8188.proxy.runpod.net" \
    --prompt "Test" \
    --workflow "nonexistent.json" \
    --local-output ./test_output/
```

**Expected Results:**
- ✅ Script exits before submission
- ✅ Error message: "Workflow file not found"
- ✅ No pod submission attempted
- ✅ Clean failure (no partial recovery files)

### Test 3.4: Missing Required Parameters
```bash
# Missing prompt
./comfy-run-remote.sh \
    --pod-url "https://zu9sxe2gu0lswm-8188.proxy.runpod.net" \
    --local-output ./test_output/

# Missing pod URL (and no auto-detect available)
./comfy-run-remote.sh \
    --prompt "Test" \
    --local-output ./test_output/
```

**Expected Results:**
- ✅ Script exits with usage error
- ✅ Help message displayed
- ✅ Missing parameter clearly identified
- ✅ Examples provided for correct usage

### Test 3.5: Network Interruption During Polling
```bash
# Start workflow
DEBUG=1 ./comfy-run-remote.sh \
    --pod-url "https://zu9sxe2gu0lswm-8188.proxy.runpod.net" \
    --prompt "Test" \
    --local-output ./test_output/ 2>&1 | tee network_test.log &

SCRIPT_PID=$!

# Simulate network interruption (if possible)
# sleep 3 && sudo iptables -A OUTPUT -d {POD_IP} -j DROP

# Wait for script to handle interruption
wait $SCRIPT_PID
RESULT=$?

# Check behavior
grep -i "retry\|retry\|connection\|error" network_test.log
```

**Expected Results:**
- ✅ Script attempts retry with backoff
- ✅ Exponential backoff delay observed (1s, 2s, 4s, 8s, 16s)
- ✅ Max 5 retry attempts
- ✅ Recovery file created if still failing

### Test 3.6: Execution Error in Workflow
```bash
# Create invalid workflow (missing required model)
cat > invalid_workflow.json << 'EOF'
{
  "1": {
    "class_type": "CheckpointLoaderSimple",
    "inputs": {"ckpt_name": "nonexistent_model.safetensors"}
  }
}
EOF

./comfy-run-remote.sh \
    --pod-url "https://zu9sxe2gu0lswm-8188.proxy.runpod.net" \
    --prompt "Test" \
    --workflow "invalid_workflow.json" \
    --local-output ./test_output/ 2>&1 | tee exec_error.log
```

**Expected Results:**
- ✅ Workflow submission succeeds
- ✅ Error detected during execution
- ✅ Error message extracted from pod response
- ✅ "WORKFLOW EXECUTION ERROR" header displayed
- ✅ Error details show missing model

## Enhanced Error Handling Tests

### Test Execution Error Extraction (New)
```bash
# Test that execution errors are properly extracted from pod responses
DEBUG=1 ./comfy-run-remote.sh \
  --pod-url "$POD_URL" \
  --prompt "test" \
  --workflow "invalid_workflow.json"  # Intentionally invalid

# Expected: Script should extract and display error details
# Log output should show: "WORKFLOW EXECUTION ERROR" with error details
```

### Test Download Retry Logic (New)
```bash
# Test that downloads retry on failure
DEBUG=1 ./comfy-run-remote.sh \
  --pod-url "$POD_URL" \
  --prompt "test" \
  --local-output "./retry_test/"

# Expected: If download fails, should retry up to 3 times
# Log should show: "Retrying download (attempt 2/3)" messages
```

### Test File Conflict Resolution (New)
```bash
# Generate first image
./comfy-run-remote.sh \
  --pod-url "$POD_URL" \
  --prompt "test" \
  --image-id "test_001" \
  --local-output "./conflict_test/"

# Generate second image (same prompt/seed will cause same filename)
./comfy-run-remote.sh \
  --pod-url "$POD_URL" \
  --prompt "test" \
  --image-id "test_001" \
  --local-output "./conflict_test/"

# Expected: Second image should be renamed (e.g., ComfyUI_00001_1.png)
# Log should show: "File conflict resolved: renamed to ..."
```

### Test Recovery File Creation (New)
```bash
# Test that timeout creates recovery file
./comfy-run-remote.sh \
  --pod-url "$POD_URL" \
  --prompt "test" \
  --timeout 5  # Very short timeout

# Expected: After timeout, check:
ls logs/recovery/
# Should see: prompt_YYYYMMDD_HHMMSS.recovery

# Check recovery file contents:
cat logs/recovery/prompt_*.recovery
# Should show: PROMPT_ID, POD_URL, recovery instructions
```

## Debugging Tests

### Enable Verbose Output
```bash
bash -x test-remote-runner.sh 2>&1 | tee debug.log
```

### Check Specific Test
```bash
# Extract and run a single test
source test-remote-runner.sh
test_help_and_validation
```

### Manual API Testing
```bash
POD_URL="http://104.255.9.187:8188"
CLIENT_ID="manual-test-$(date +%s)"

# Submit test workflow
curl -X POST "$POD_URL/prompt" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": {"1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "model.safetensors"}}},
    "client_id": "'$CLIENT_ID'"
  }' | jq .
```

### Test Error Extraction
```bash
# Simulate execution error response
POD_URL="https://example-8188.proxy.runpod.net"
PROMPT_ID="test-id-123"

# Check what error extraction would return
curl -s "$POD_URL/history/$PROMPT_ID" | jq ".\"$PROMPT_ID\".status"
```

## Next Steps After Tests Pass

1. **Implement comfy-run-remote.sh**
   - Use test results to validate implementation
   - Follow the plan at `.claude/plans/clever-swimming-breeze.md`

2. **Run Integration Tests**
   - Test actual workflow submission
   - Test image download
   - Test error scenarios

3. **Benchmark Performance**
   - Compare with local comfy-run.sh
   - Measure overhead
   - Document results

4. **Create Production Tests**
   - Batch processing
   - Concurrent submissions
   - Long-running workflows

## Contact & Support

For test failures or issues:
1. Check `TEST_VALUES.md` for expected values
2. Review test logs: `tail -50 test-results.log`
3. Run connectivity test: `bash test-pod-connectivity.sh`
4. Check pod status: `runpodctl pod status zu9sxe2gu0lswm`

