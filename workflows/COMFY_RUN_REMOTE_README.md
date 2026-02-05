# comfy-run-remote.sh - Remote ComfyUI Workflow Executor

A complete bash script for executing ComfyUI workflows on remote RunPod instances from your localhost. Handles workflow submission, progress monitoring, and automatic image download.

## Quick Start

### 1. Get Your Pod URL

```bash
# Get current pod ID (changes daily!)
runpodctl pod list

# Output shows something like: zu9sxe2gu0lswm

# Set environment variable with RunPod proxy URL
export RUNPOD_POD_URL="https://zu9sxe2gu0lswm-8188.proxy.runpod.net"
```

### 2. Run a Workflow

```bash
./comfy-run-remote.sh --prompt "A red car"
```

### 3. Get Your Images

```bash
# Images downloaded to ./output/ automatically
ls -lh ./output/
```

## Usage

### Basic Usage (with environment variable)

```bash
export RUNPOD_POD_URL="https://x08qt40klp2ls4-8188.proxy.runpod.net"
./comfy-run-remote.sh --prompt "A beautiful sunset over mountains"
```

### Full Specification

```bash
./comfy-run-remote.sh \
    --prompt "A red car" \
    --pod-url https://x08qt40klp2ls4-8188.proxy.runpod.net \
    --image-id "batch_001" \
    --seed 12345 \
    --local-output ./my_images/ \
    --timeout 300
```

### Batch Processing

```bash
export RUNPOD_POD_URL="https://x08qt40klp2ls4-8188.proxy.runpod.net"

# Generate 5 images
for i in {1..5}; do
    ./comfy-run-remote.sh \
        --prompt "Image number $i" \
        --image-id "batch_$(printf '%03d' $i)"
done
```

### Without Downloading Images

```bash
./comfy-run-remote.sh \
    --prompt "Test prompt" \
    --pod-url https://x08qt40klp2ls4-8188.proxy.runpod.net \
    --no-download
```

## Command-Line Options

### Required

| Option | Example | Description |
|--------|---------|-------------|
| `--prompt TEXT` | `--prompt "A red car"` | The prompt text to generate |

### Remote Pod (One Required)

| Option | Default | Description |
|--------|---------|-------------|
| `--pod-url URL` | None | RunPod proxy URL |
| `RUNPOD_POD_URL` env var | None | Alternative to --pod-url |

### Optional

| Option | Default | Description |
|--------|---------|-------------|
| `--workflow FILE` | `flux2_turbo_512x512_parametric_api.json` | Workflow JSON file |
| `--image-id ID` | `UNDEFINED_ID_` | Unique identifier for generation |
| `--seed SEED` | Auto-generated | Random seed for reproducibility |
| `--output-folder PATH` | `/workspace/output/` | Remote pod output folder |
| `--local-output PATH` | `./output/` | Local download directory |
| `--timeout SECONDS` | `3600` | Max execution time in seconds |
| `--download / --no-download` | `--download` | Enable/disable image download |
| `--help, -h` | N/A | Show help message |

## Examples

### Example 1: Simple Generation

```bash
export RUNPOD_POD_URL="https://x08qt40klp2ls4-8188.proxy.runpod.net"
./comfy-run-remote.sh --prompt "A robot"
```

**Output:**
```
[INFO] ComfyUI Remote Workflow Execution
[INFO] Pod URL: https://x08qt40klp2ls4-8188.proxy.runpod.net
[✓] Pod is accessible (HTTP 200)
[✓] Workflow structure is valid
[✓] Workflow submitted! Prompt ID: abc123...
[✓] Workflow completed!
[✓] Downloaded: Flux2_Turbo_00001_.png
[✓] Remote generation completed successfully!
```

### Example 2: Full Specification

```bash
./comfy-run-remote.sh \
    --prompt "A sci-fi city at night" \
    --pod-url https://x08qt40klp2ls4-8188.proxy.runpod.net \
    --image-id "scifi_001" \
    --seed 42 \
    --local-output /tmp/images/ \
    --timeout 300 \
    --workflow flux2_turbo_512x512_api.json
```

### Example 3: Batch with Loop

```bash
export RUNPOD_POD_URL="https://x08qt40klp2ls4-8188.proxy.runpod.net"

# Generate 10 images in a loop
for i in $(seq 1 10); do
    ./comfy-run-remote.sh \
        --prompt "Landscape number $i" \
        --image-id "landscape_$(printf '%03d' $i)"
    echo "Generated image $i"
done
```

### Example 4: Custom Workflow

```bash
./comfy-run-remote.sh \
    --prompt "A portrait" \
    --pod-url https://x08qt40klp2ls4-8188.proxy.runpod.net \
    --workflow my_custom_workflow.json \
    --image-id "portrait_001"
```

## Features

### ✅ Fully Functional

- **Pod Connectivity**: Validates pod is accessible before submission
- **Workflow Submission**: Submits workflows with automatic format detection
- **Progress Monitoring**: Polls pod every 2 seconds with progress updates
- **Image Download**: Automatically downloads generated images
- **Error Recovery**: Retries with exponential backoff on failures
- **Comprehensive Logging**: Logs all operations to file and console

### ✅ Supported Workflows

- UI format workflows (node-based)
- API format workflows (JSON with "prompt" wrapper)
- API format workflows (direct numbered nodes)
- Variable substitution (${PROMPT}, ${SEED}, etc.)

### ✅ Pod URL Formats

All of these work:
- `https://x08qt40klp2ls4-8188.proxy.runpod.net`
- `x08qt40klp2ls4-8188.proxy.runpod.net` (adds https://)
- `https://x08qt40klp2ls4-8188.proxy.runpod.net/` (removes trailing slash)

### ✅ Robust Error Handling

- Network timeouts with retries
- Invalid workflow detection
- Pod accessibility checks
- Download failure recovery
- Comprehensive error messages

## Dependencies

All dependencies are standard and usually pre-installed:

| Dependency | Usage | Status |
|------------|-------|--------|
| `bash` | Script execution | Required |
| `curl` | HTTP requests | Required |
| `jq` | JSON parsing | Required |
| `python3` | Workflow conversion | Required |
| `date` | Timestamp generation | Required |
| `xxd` | Binary file validation | Required |

Install on Ubuntu/Debian:
```bash
sudo apt-get install -y curl jq python3 vim-common
```

## Workflow Files

Available workflows in the directory:

| File | Format | Description |
|------|--------|-------------|
| `flux2_turbo_512x512_api.json` | API | Simple API format workflow ✅ TESTED |
| `flux2_turbo_512x512_parametric_api.json` | UI | UI format with variables ✅ TESTED |
| `flux2_turbo_512x512.json` | UI | UI format |
| `flux2_turbo_default_api.json` | API | Default API format |

**Recommended**: Use `flux2_turbo_512x512_api.json` for best compatibility.

## Important Notes

### ⚠️ Pod ID Changes Daily

The pod ID changes when the pod is restarted. Always get a fresh ID:

```bash
# Get current pod ID
runpodctl pod list

# Set the URL with the NEW pod ID
export RUNPOD_POD_URL="https://NEW_POD_ID-8188.proxy.runpod.net"
```

### ⚠️ Initial Model Load Delay

The first workflow execution takes 30-60 seconds for the model to load to VRAM. Subsequent runs are much faster (5-15 seconds). The default timeout of 3600 seconds accommodates this.

### ✅ Network Resilience

The script automatically retries failed operations with exponential backoff:
- Retry 1: 1 second
- Retry 2: 2 seconds
- Retry 3: 4 seconds
- Retry 4: 8 seconds
- Retry 5: 16 seconds

## Logging

All generations are logged to `./logs/generations/generation_TIMESTAMP.log`

View the log:
```bash
# Latest generation
cat logs/generations/generation_*.log | tail -20

# All logs
ls -lh logs/generations/
```

Log includes:
- Input parameters
- Pod connectivity status
- Workflow submission details
- Polling progress
- Image download status
- Any errors encountered

## Troubleshooting

### "Pod URL not provided"

**Problem**: Script didn't find pod URL

**Solution**:
```bash
# Set environment variable
export RUNPOD_POD_URL="https://x08qt40klp2ls4-8188.proxy.runpod.net"

# OR provide --pod-url parameter
./comfy-run-remote.sh --prompt "test" --pod-url https://...
```

### "Pod unreachable"

**Problem**: Can't connect to pod

**Cause**: Wrong pod URL or pod not running

**Solution**:
```bash
# Get current pod ID (changes daily!)
runpodctl pod list

# Update URL with new pod ID
export RUNPOD_POD_URL="https://NEW_ID-8188.proxy.runpod.net"

# Test manually
curl https://x08qt40klp2ls4-8188.proxy.runpod.net/system_stats
```

### "Workflow validation failed"

**Problem**: Workflow format not recognized

**Cause**: Incompatible workflow file

**Solution**:
```bash
# Use a tested workflow file
./comfy-run-remote.sh --prompt "test" --workflow flux2_turbo_512x512_api.json

# Or check workflow is valid JSON
jq . your_workflow.json
```

### "Download failed"

**Problem**: Images didn't download

**Cause**: Output directory permissions or pod error

**Solution**:
```bash
# Check output directory
ls -ld ./output/

# Create if missing
mkdir -p ./output/

# Run with different output directory
./comfy-run-remote.sh --prompt "test" --local-output /tmp/images/
```

### "Timeout after 3600s"

**Problem**: Workflow took too long

**Cause**: Pod busy or large model loading

**Solution**:
```bash
# Increase timeout to 2 hours
./comfy-run-remote.sh --prompt "test" --timeout 7200

# Or submit without waiting for download
./comfy-run-remote.sh --prompt "test" --no-download
```

## Performance

### Typical Timings

**First Run (model loading)**:
- Pod connectivity check: <1s
- Workflow submission: 1-2s
- Model loading: 30-60s
- Workflow execution: 5-15s
- Image download: 2-5s
- **Total: 40-85 seconds**

**Subsequent Runs (cached model)**:
- Pod connectivity check: <1s
- Workflow submission: 1-2s
- Workflow execution: 5-10s
- Image download: 2-5s
- **Total: 8-20 seconds**

### Resource Usage

- **CPU**: Low (mostly waiting for pod)
- **Memory**: 10-50 MB
- **Network**: ~2-5 MB per image
- **Disk**: Depends on image size (typically 400-500 KB)

## Advanced Usage

### Debug Mode

```bash
DEBUG=1 ./comfy-run-remote.sh --prompt "test" --pod-url https://...
```

Shows detailed debug information for troubleshooting.

### Custom Seeds for Reproducibility

```bash
# Generate same image with same seed
./comfy-run-remote.sh --prompt "A red car" --seed 12345

# Run again with same seed produces identical output
./comfy-run-remote.sh --prompt "A red car" --seed 12345
```

### Parallel Execution

```bash
export RUNPOD_POD_URL="https://x08qt40klp2ls4-8188.proxy.runpod.net"

# Run 3 jobs in parallel
./comfy-run-remote.sh --prompt "Image 1" --image-id "job_001" &
./comfy-run-remote.sh --prompt "Image 2" --image-id "job_002" &
./comfy-run-remote.sh --prompt "Image 3" --image-id "job_003" &

# Wait for all to complete
wait

echo "All jobs completed!"
```

**Note**: Parallel execution depends on pod resources. Single GPU pods may queue jobs internally.

## Workflow Compatibility

The script works with ComfyUI workflows in these formats:

### ✅ Supported

- ComfyUI UI format (web interface JSON export)
- ComfyUI API format (REST API JSON)
- Flux.2 Turbo workflows
- Workflows with variable placeholders (${PROMPT}, ${SEED})

### ⚠️ May Need Adjustment

- Very large models (>50GB)
- Multiple GPU workflows
- Custom nodes not installed on pod
- Workflows requiring specific hardware

## Related Scripts

- `comfy-run.sh` - Local ComfyUI execution (runs workflows on localhost)
- `test-remote-runner.sh` - Test suite for remote execution
- `test-pod-connectivity.sh` - Pod connectivity diagnostics

## Contributing

To improve the script:

1. Test with various workflow types
2. Report any issues with specific models or configurations
3. Suggest performance optimizations
4. Add support for additional workflow formats

## License

Same as parent project (ComfyUI remote execution tool)

## Support

For issues:

1. Check the troubleshooting section above
2. Review generation logs: `tail logs/generations/generation_*.log`
3. Verify pod is running: `runpodctl pod list`
4. Test pod manually: `curl https://POD_ID-8188.proxy.runpod.net/system_stats`

## Changelog

### v1.0.0 (2026-02-01)
- Initial release
- Full workflow submission support
- Image download functionality
- Comprehensive error handling
- Detailed logging
- Support for multiple workflow formats

---

**Version**: 1.0.0
**Status**: Production Ready
**Last Updated**: 2026-02-01
**Tested On**: RunPod GPU instances with ComfyUI
**Recommended Workflow**: flux2_turbo_512x512_api.json
