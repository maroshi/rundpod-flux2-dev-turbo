# ComfyUI Workflow Runner (comfy-run.sh) - Complete Guide

## Overview

`comfy-run.sh` is an enterprise-grade bash script for executing ComfyUI workflows via REST API with comprehensive parameter injection, logging, and error handling. It handles both ComfyUI UI format and API format workflows with automatic conversion.

**Version:** 2.1.0
**Last Updated:** 2026-01-31

### Key Features

✓ **Parameter Substitution** - Dynamic injection of prompts, seeds, image IDs, output folders
✓ **Format Auto-Conversion** - Converts ComfyUI UI format workflows to API format automatically
✓ **Comprehensive Logging** - Detailed audit trails with timestamps, parameters, and execution logs
✓ **REST API Integration** - Full ComfyUI REST API support with polling and timeout handling
✓ **Seed Management** - Auto-generation with collision prevention via epoch time + random
✓ **Filename Normalization** - Converts 5-digit to 2-digit output filename suffixes
✓ **Auto-Dependency Installation** - Installs missing gettext-base (envsubst) automatically
✓ **Error Recovery** - Graceful error handling with detailed error messages
✓ **Progress Monitoring** - Real-time feedback on workflow execution with elapsed time

---

## Quick Start

### Basic Usage

```bash
# Minimal - auto-generates seed, uses default workflow
./comfy-run.sh --prompt "A beautiful sunset"

# With image ID for tracking
./comfy-run.sh --prompt "A beautiful sunset" --image-id "batch_001_001"

# Full control
./comfy-run.sh \
    --prompt "A beautiful sunset" \
    --image-id "batch_001_001" \
    --workflow flux2_turbo_512x512_parametric_api.json \
    --output-folder /workspace/outputs/ \
    --seed 42
```

### Help System

```bash
./comfy-run.sh --help
./comfy-run.sh -h
```

---

## Command-Line Arguments

### Required

| Argument | Example | Description |
|----------|---------|-------------|
| `--prompt TEXT` | `--prompt "A red car"` | The prompt text passed to the workflow (required) |

### Optional

| Argument | Default | Description |
|----------|---------|-------------|
| `--workflow FILE` | `flux2_turbo_default_api.json` | Workflow JSON file (UI or API format) |
| `--image-id ID` | (none) | Unique identifier, appended to prompt for cache busting |
| `--output-folder PATH` | `/workspace/output/` | Directory for output images |
| `--seed SEED` | (auto-generated) | Reproducibility seed (overrides auto-generation) |
| `--help, -h` | (none) | Display help message and exit |

### Examples

#### Batch Processing

```bash
# Process 10 images in sequence
for i in {1..10}; do
    ./comfy-run.sh \
        --prompt "Image $i" \
        --image-id "batch_001_$(printf '%03d' $i)"
done
```

#### Parallel Execution

```bash
# Run 3 workflows in parallel
./comfy-run.sh --prompt "Job 1" --image-id "job_001" &
./comfy-run.sh --prompt "Job 2" --image-id "job_002" &
./comfy-run.sh --prompt "Job 3" --image-id "job_003" &
wait  # Wait for all jobs to complete
```

#### Custom Configuration

```bash
# Override ComfyUI server location
export COMFYUI_HOST="192.168.1.100"
export COMFYUI_PORT="9000"
export GENERATION_LOG_DIR="/custom/logs/"

./comfy-run.sh --prompt "Test on remote server"
```

---

## Environment Variables

Configure behavior via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `COMFYUI_HOST` | `localhost` | ComfyUI server hostname |
| `COMFYUI_PORT` | `8188` | ComfyUI server port |
| `GENERATION_LOG_DIR` | `/workspace/logs/generations/` | Logging directory |
| `DEBUG` | `0` | Set to `1` to enable debug logging |

### Example

```bash
export COMFYUI_HOST="192.168.1.100"
export COMFYUI_PORT="9000"
export GENERATION_LOG_DIR="/var/logs/comfyui/"
export DEBUG=1

./comfy-run.sh --prompt "Test"
```

---

## Output Files

The script creates several output files:

### Generated Images

```
{OUTPUT_FOLDER}/{IMAGE_ID}_{HH}{MM}{SS}_*.png
```

Example: `/workspace/output/batch_001_001_153045_00001.png`

### Generation Logs

```
{GENERATION_LOG_DIR}/generation_{TIMESTAMP}.log
```

Example: `/workspace/logs/generations/generation_20260131_153019.log`

Contains:
- Generation metadata (timestamp, client ID)
- Input parameters (prompt, seed, image ID, workflow)
- Execution timeline (start/end times)
- Server accessibility checks
- Workflow validation results
- API submission and polling details
- Final output status and file locations
- All errors with context

### Debug Payload

```
/tmp/comfyui-payload-{TIMESTAMP}.json
```

Full JSON payload submitted to ComfyUI API (for troubleshooting)

---

## Return Codes

| Code | Meaning | Example Cause |
|------|---------|---------------|
| `0` | Success | Workflow completed successfully |
| `1` | Error | Missing dependency, validation failure, API error |
| `2` | Timeout | Workflow exceeded 1-hour (3600 second) execution limit |

### Usage in Scripts

```bash
./comfy-run.sh --prompt "Test" --image-id "test_001"
EXIT_CODE=$?

case $EXIT_CODE in
    0)
        echo "Success!"
        ;;
    1)
        echo "Execution failed"
        ;;
    2)
        echo "Timeout - workflow took too long"
        ;;
esac
```

---

## Workflow Support

### Workflow Formats

The script supports **both** ComfyUI workflow formats:

1. **UI Format** (`.json` exported from web interface)
   - Has `nodes` array and `links` array
   - References node connections by link IDs
   - Script auto-converts to API format

2. **API Format** (native REST API format)
   - Nodes as top-level dictionary keyed by node ID
   - Direct node references via `[node_id, output_slot]`
   - Ready for API submission

### Workflow Requirements

All workflows must contain:

- **CLIPTextEncode node** - Accepts the text prompt
- **SaveImage node** - Outputs the generated image

The script validates these requirements before submission.

### Workflow Registry

Available workflows are registered in `workflows.conf`:

```
turbo-512        Fast Flux.2 Turbo at 512x512 (6-8 seconds)
turbo-1024       Quality Flux.2 Turbo at 1024x1024 (10-12 seconds)
turbo-advanced   Variable step count (6-30 seconds)
turbo-reference  6-image reference conditioning (variable time)
```

### Parameter Placeholders

Workflows can use these placeholders (substituted via `envsubst`):

- `${PROMPT}` - The user-provided prompt text
- `${SEED}` - The seed value
- `${IMAGE_ID}` - Unique identifier
- `${OUTPUT_FOLDER}` - Output directory path
- `${FILENAME_PREFIX}` - Generated filename prefix

Example in workflow:

```json
{
  "prompt_text": "${PROMPT} (id: ${IMAGE_ID})",
  "seed": "${SEED}",
  "output_path": "${OUTPUT_FOLDER}"
}
```

---

## Architecture & Functions

The refactored script uses modular functions for clear separation of concerns:

### Utility & Logging

- `log_info()` - Info messages to stdout
- `log_success()` - Success messages to stdout
- `log_error()` - Error messages to stderr
- `log_debug()` - Debug messages (only if `DEBUG=1`)

### Initialization & Validation

- `parse_arguments()` - Parse command-line arguments
- `validate_arguments()` - Check required arguments and workflow file
- `generate_seed()` - Create seed if not provided
- `compute_derived_values()` - Calculate FILENAME_PREFIX and cache-busting prompt
- `export_variables()` - Export for subprocess use
- `print_startup_info()` - Display configuration summary

### Dependency & Accessibility Checks

- `check_command()` - Verify command exists in PATH
- `verify_dependencies()` - Check curl, jq, python3, envsubst
- `check_comfyui_accessibility()` - Verify ComfyUI server is responding
- `validate_workflow_structure()` - Verify required nodes exist

### Workflow Processing

- `process_workflow_template()` - Substitute environment variables
- `convert_ui_to_api_format()` - Convert UI to API format (Python)
- `substitute_seed()` - Replace seed in KSampler nodes (Python)

### API Interaction

- `submit_workflow()` - POST workflow to `/prompt` endpoint
- `poll_for_completion()` - Poll `/history` until completion
- `handle_completion_response()` - Process success or error response
- `normalize_output_filenames()` - Rename files with consistent suffix

### Logging

- `init_generation_log()` - Create log file with header
- `log_to_file()` - Append timestamped message to log
- `finalize_generation_log()` - Add completion info and close log

---

## Execution Flow

```
1. Parse Arguments
2. Validate Arguments
3. Verify Dependencies (curl, jq, python3, envsubst)
4. Check ComfyUI Accessibility
5. Validate Workflow Structure
6. Process Workflow Template (variable substitution)
7. Convert UI → API Format
8. Substitute Seed in KSampler Nodes
9. Submit Workflow to ComfyUI
10. Poll for Completion (every 2 seconds, max 1 hour)
11. Handle Response (success/failure)
12. Normalize Output Filenames
13. Finalize Logging
```

---

## Troubleshooting

### "ComfyUI server not accessible"

```
Problem: Can't reach ComfyUI server
Solutions:
  1. Check ComfyUI is running: curl localhost:8188/system_stats
  2. Verify COMFYUI_HOST and COMFYUI_PORT environment variables
  3. Check firewall (if remote): telnet $COMFYUI_HOST $COMFYUI_PORT
  4. Review generation log: cat /workspace/logs/generations/generation_*.log
```

### "Workflow file not found"

```
Problem: Specified workflow doesn't exist
Solutions:
  1. List available workflows: ls -la *.json
  2. Use absolute path: ./comfy-run.sh --workflow /full/path/to/workflow.json
  3. Check file exists: test -f workflow.json && echo "exists"
  4. Check permissions: ls -l workflow.json (should be readable)
```

### "Failed to install envsubst"

```
Problem: gettext-base installation failed
Solutions:
  1. Run with sudo if available
  2. Install manually: sudo apt-get install -y gettext-base
  3. Check apt: apt-get update && apt-get upgrade
  4. Use container with pre-installed gettext-base
```

### "Failed to get prompt_id from response"

```
Problem: ComfyUI rejected the workflow
Solutions:
  1. Review debug payload: cat /tmp/comfyui-payload-*.json | jq .
  2. Check generation log for validation errors
  3. Verify workflow has CLIPTextEncode and SaveImage nodes
  4. Check ComfyUI logs for detailed error info
  5. Validate workflow syntax: jq empty workflow.json
```

### "Workflow execution failed"

```
Problem: Workflow ran but produced error
Solutions:
  1. Check generation log for error messages
  2. Review ComfyUI UI for missing models or nodes
  3. Ensure all required models are installed
  4. Check VRAM availability: nvidia-smi
  5. Review workflow connections are valid
```

### "Workflow did not complete within timeout period"

```
Problem: Workflow exceeded 1 hour (3600 second) limit
Solutions:
  1. Check workflow is actually running: ps aux | grep comfyui
  2. Monitor ComfyUI queue: curl localhost:8188/queue
  3. Check for stuck processes: ps aux | grep python
  4. Try killing and restarting ComfyUI
  5. Consider breaking into smaller workflows
```

---

## Performance Notes

### Timing Breakdown

| Component | Typical Time |
|-----------|--------------|
| Validation & checks | <100ms |
| Workflow processing | 50-200ms (varies with workflow size) |
| API submission | 100-200ms |
| Model loading (first time) | 5-20 seconds |
| Model loading (cached) | <100ms |
| Image generation | 6-30 seconds (depends on workflow) |
| Polling response time | ~50-100ms per check |

### Optimization Tips

1. **Reuse same workflow** - Keeps models loaded in VRAM
2. **Batch operations** - Run multiple images sequentially to share model memory
3. **Parallel execution** - Run with `&` and `wait` for concurrent generation
4. **Monitor resources** - Use `nvidia-smi` to watch VRAM usage
5. **Pre-warm models** - Run a test workflow before batch to load models

### Known Limitations

- Max workflow execution: 1 hour (configurable via `MAX_POLLS`)
- Max seed value: 2^31-1 (standard 32-bit int)
- Max concurrent connections: ComfyUI default (typically 32)

---

## Logging & Debugging

### Enable Debug Mode

```bash
export DEBUG=1
./comfy-run.sh --prompt "Test"
```

Output includes:
- Command availability checks
- Variable values
- Function call tracing

### Review Generation Logs

```bash
# View most recent log
tail -f /workspace/logs/generations/generation_*.log

# Search for errors
grep "ERROR" /workspace/logs/generations/*.log

# View specific run
cat /workspace/logs/generations/generation_20260131_153019.log
```

### Inspect Debug Payload

```bash
# Pretty-print JSON payload
cat /tmp/comfyui-payload-*.json | jq . | less

# Count nodes in payload
cat /tmp/comfyui-payload-*.json | jq 'keys | length'

# List all node types
cat /tmp/comfyui-payload-*.json | jq '[.[] | .class_type] | unique'
```

### Monitor ComfyUI State

```bash
# Check system stats
curl localhost:8188/system_stats | jq .

# View execution queue
curl localhost:8188/queue | jq .

# Get execution history
curl localhost:8188/history | jq 'keys | length'

# View specific prompt
curl localhost:8188/history/{PROMPT_ID} | jq .
```

---

## Advanced Usage

### Custom Seed Management

```bash
# Use fixed seed for reproducibility
./comfy-run.sh --prompt "Test" --seed 12345

# Use timestamp-based seed
SEED=$(date +%s)
./comfy-run.sh --prompt "Test" --seed $SEED

# Generate seed from random source
SEED=$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')
./comfy-run.sh --prompt "Test" --seed $SEED
```

### Conditional Execution

```bash
# Only run if ComfyUI is available
if curl -s localhost:8188/system_stats > /dev/null; then
    ./comfy-run.sh --prompt "Test"
else
    echo "ComfyUI not available"
    exit 1
fi
```

### Integration with External Systems

```bash
# Submit to queue and return immediately
./comfy-run.sh --prompt "Test" &
JOB_PID=$!

# Do other work while generation runs
echo "Workflow submitted with PID: $JOB_PID"

# Wait for completion
wait $JOB_PID
RESULT=$?

if [ $RESULT -eq 0 ]; then
    echo "Workflow completed successfully"
fi
```

### Workflow Templating

Create workflow template with placeholders:

```json
{
  "class_type": "CLIPTextEncode",
  "inputs": {
    "text": "${PROMPT}",
    "clip": [1, 0]
  }
}
```

Then use variables:

```bash
export WIDTH=768
export HEIGHT=768
./comfy-run.sh --prompt "Wide image" --workflow my_template.json
```

---

## Maintenance

### Log Rotation

```bash
# Clean up old logs (keep last 100)
ls -t /workspace/logs/generations/*.log | tail -n +101 | xargs rm -f

# Automatic cleanup in cron
# Add to crontab: 0 0 * * * find /workspace/logs/generations -mtime +7 -delete
```

### Performance Monitoring

```bash
# Average generation time
grep "Still processing" /workspace/logs/generations/*.log | \
    awk '{print $NF}' | \
    awk -F's' '{sum+=$1; n++} END {print "Average:", sum/n "s"}'
```

### Payload Cleanup

```bash
# Clean up old debug payloads
rm -f /tmp/comfyui-payload-*.json

# Keep last 5 days
find /tmp/comfyui-payload-*.json -mtime +5 -delete
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.1.0 | 2026-01-31 | Complete refactor with modular functions, comprehensive documentation, help system |
| 2.0.0 | 2026-01-28 | Workflow registry, filename normalization |
| 1.0.0 | 2026-01-13 | Initial release |

---

## Support & Resources

- **ComfyUI Docs:** https://docs.comfy.org
- **GitHub Issues:** https://github.com/Comfy-Org/ComfyUI/issues
- **Discord Community:** https://discord.gg/comfyui
- **Generation Logs:** `/workspace/logs/generations/`

---

## License

MIT - See parent repository for details

---

**Last Updated:** 2026-01-31
**Author:** ComfyUI Community
