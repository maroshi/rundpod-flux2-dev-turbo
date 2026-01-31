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
| `test-remote-runner.sh` | Comprehensive test suite | 5-10 min | Optional |
| `test-pod-connectivity.sh` | Pod connectivity & diagnostics | 2-3 min | Yes |
| `test-workflow-api.sh` | API interaction testing | 3-5 min | Yes |

## Quick Start

### 1. Run All Tests at Once
```bash
cd rundpod-flux2-dev-turbo/workflows/

# Make scripts executable
chmod +x test-*.sh comfy-run-remote.sh

# Run comprehensive test suite
bash test-remote-runner.sh

# View results
cat test-results.log
```

### 2. Run Connectivity Tests
```bash
bash test-pod-connectivity.sh
```

This will:
- Check pod accessibility at configured URL
- Test HTTP endpoints
- Test SSH connectivity
- Verify dependencies
- Show system diagnostics

### 3. Run API Tests
```bash
bash test-workflow-api.sh
```

This will:
- Verify pod is accessible
- Fetch pod information
- Test API response parsing
- Validate workflow JSON
- Run stress tests

### 4. Run Specific Test Suite
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

### To Be Tested (After Script Implementation)
- ⏳ Actual workflow submission
- ⏳ Remote execution and polling
- ⏳ Image download
- ⏳ Retry logic
- ⏳ Full end-to-end workflow

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

