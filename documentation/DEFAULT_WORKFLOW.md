# Auto-Load Default Workflow

This feature allows you to configure ComfyUI to automatically load a specific workflow on startup using an environment variable.

## How It Works

When you set the `DEFAULT_WORKFLOW_URL` environment variable in your RunPod template, the startup script will:

1. **Download** the workflow JSON file from the specified URL
2. **Save** it to `/workspace/ComfyUI/user/default/workflows/`
3. **Configure** ComfyUI to automatically load this workflow on startup

## Setup in RunPod Template

### Option 1: Use a Direct URL

Add this environment variable to your RunPod template:

```bash
DEFAULT_WORKFLOW_URL=https://example.com/path/to/your/workflow.json
```

### Option 2: Use GitHub Raw URL

If your workflow is hosted on GitHub:

```bash
DEFAULT_WORKFLOW_URL=https://raw.githubusercontent.com/username/repo/main/workflows/my_workflow.json
```

### Option 3: Use the Built-in FLUX 2 Turbo Workflow

To use the FLUX 2 Turbo workflow included in this image:

```bash
DEFAULT_WORKFLOW_URL=https://raw.githubusercontent.com/maroshi/rundpod-flux2-dev-turbo/main/workflows/flux2_turbo_default.json
```

## Example RunPod Template Configuration

```yaml
name: "ComfyUI FLUX 2 with Custom Workflow"
docker_image: "your-image:tag"
environment_variables:
  - key: DEFAULT_WORKFLOW_URL
    value: "https://raw.githubusercontent.com/username/repo/main/workflow.json"
  - key: COMFYUI_VRAM_MODE
    value: "HIGH_VRAM"
```

## Workflow Requirements

Your workflow JSON file must be:
- **Valid ComfyUI workflow format** (exported from ComfyUI)
- **Publicly accessible** via HTTP/HTTPS
- **Contains all required nodes** that are installed in this image

## Behavior

- **First Start**: Downloads and configures the workflow
- **Subsequent Starts**: Skips download if file already exists, ensures it's set as default
- **No URL Set**: Falls back to built-in workflows

## Troubleshooting

### Workflow doesn't load
- Check that the URL is publicly accessible
- Verify the workflow JSON is valid ComfyUI format
- Check startup logs for download errors

### Missing nodes error
- Ensure all custom nodes required by your workflow are installed in the Docker image
- Add custom node installation to your Dockerfile if needed

## Technical Details

- **Storage Location**: `/workspace/ComfyUI/user/default/workflows/`
- **Settings File**: `/workspace/ComfyUI/user/default/comfy.settings.json`
- **Setting Key**: `Comfy.PreviousWorkflow`

## See Also

- [Workflow Examples](../workflows/)
- [Custom Models Guide](./MODELS.md)
- [RunPod Configuration](./RUNPOD.md)
