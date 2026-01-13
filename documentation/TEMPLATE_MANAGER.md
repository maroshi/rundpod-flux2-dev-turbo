# Template Manager Configuration

This document explains the ComfyUI template manager system and how to minimize its impact on startup.

## Research Summary

### What is the Template Manager?

The template manager is a feature in ComfyUI that allows users to browse and select workflow templates when starting ComfyUI. Templates are stored in:
- **User templates**: `ComfyUI/user/default/comfy.templates.json`
- **Workflow directory**: `ComfyUI/user/default/workflows/`

### Available Settings

Based on research of ComfyUI's codebase and documentation:

**Settings Location:**
- `ComfyUI/user/default/comfy.settings.json` - User preferences
- `ComfyUI/user/default/comfy.templates.json` - Template definitions

**Relevant Settings:**
```json
{
  "Comfy.Workflow.WorkflowTabsPosition": "Topbar",
  "Comfy.Workflow.ShowMissingNodesWarning": false,
  "Comfy.Workflow.OpenWorkflowsInNewTab": false
}
```

### Important Finding

**There is NO official setting to disable the template manager/selector dialog on startup** as of January 2026. This functionality would require either:
1. A feature addition to ComfyUI
2. Browser localStorage manipulation (not recommended)
3. Custom node extension

## Current Implementation

### What We've Done

To minimize template manager interference, this image implements:

1. **Empty Templates File**
   - Location: `configuration/comfy.templates.json`
   - Content: `[]` (empty array)
   - Result: No templates appear in the template selector

2. **Auto-Load Workflow**
   - Environment variable: `DEFAULT_WORKFLOW_URL`
   - Automatically downloads and loads your preferred workflow
   - See [DEFAULT_WORKFLOW.md](./DEFAULT_WORKFLOW.md) for details

3. **Optimized Settings**
   - Disabled workflow missing nodes warnings
   - Configured workflow tabs in topbar
   - Set workflows to open in same tab

### Configuration Files

**`configuration/comfy.settings.json`:**
```json
{
    "Comfy.DevMode": true,
    "Comfy.Minimap.Visible": false,
    "VHS.LatentPreview": false,
    "Comfy.Workflow.WorkflowTabsPosition": "Topbar",
    "Comfy.Workflow.ShowMissingNodesWarning": false,
    "Comfy.Workflow.OpenWorkflowsInNewTab": false,
    "Comfy.Graph.CanvasMenu": true
}
```

**`configuration/comfy.templates.json`:**
```json
[]
```

**`configuration/config.ini`:**
```ini
[default]
preview_method = auto
security_level = normal
network_mode = personal_cloud
# ... other settings
```

## How ComfyUI Settings Work

### Settings Hierarchy

1. **Core Settings** - Defined in `ComfyUI_frontend/src/constants/coreSettings.ts`
2. **User Settings** - Stored in `user/default/comfy.settings.json`
3. **Session Settings** - Browser localStorage (temporary)

### Settings Categories

ComfyUI has over 100 settings organized by prefix:

| Prefix | Controls |
|--------|----------|
| `Comfy.Queue.*` | Queue and execution behavior |
| `Comfy.Workflow.*` | Workflow loading and management |
| `Comfy.Graph.*` | Canvas and node graph display |
| `Comfy.Validation.*` | Validation and error checking |
| `Comfy.DevMode` | Development features |
| `Comfy.Minimap.*` | Minimap display settings |

### Accessing Settings

**Via UI:**
- Press `Ctrl + ,` to open settings panel
- Click gear icon in ComfyUI interface

**Via File:**
- Edit `ComfyUI/user/default/comfy.settings.json`
- Restart ComfyUI to apply changes

## Workarounds for Template Manager

Since there's no official "disable" setting, here are the approaches we've implemented:

### 1. Empty Templates List (Implemented)

**What it does:**
- Provides an empty `comfy.templates.json` file
- Template selector shows no templates
- Reduces visual clutter

**Implementation:**
```dockerfile
COPY configuration/comfy.templates.json user/default/comfy.templates.json
```

### 2. Auto-Load Workflow (Implemented)

**What it does:**
- Downloads workflow from `DEFAULT_WORKFLOW_URL` environment variable
- Configures ComfyUI to load this workflow automatically
- Bypasses need to select from templates

**Usage:**
```bash
DEFAULT_WORKFLOW_URL=https://example.com/my-workflow.json
```

See [DEFAULT_WORKFLOW.md](./DEFAULT_WORKFLOW.md) for complete details.

### 3. Optimized Startup Settings (Implemented)

**What it does:**
- Disables unnecessary warnings and dialogs
- Configures optimal workflow tab behavior
- Enables canvas right-click menu

**Settings:**
```json
{
    "Comfy.Workflow.ShowMissingNodesWarning": false,
    "Comfy.Workflow.OpenWorkflowsInNewTab": false,
    "Comfy.Graph.CanvasMenu": true
}
```

## Additional Settings to Try

If you want to experiment with other settings to improve startup behavior:

### Queue Settings
```json
{
    "Comfy.Queue.AutoQueueMode": "disabled",
    "Comfy.Queue.MaxHistoryItems": 16
}
```

### Validation Settings
```json
{
    "Comfy.Validation.Workflows": false
}
```

### Interface Settings
```json
{
    "Comfy.UseNewMenu": "Disabled",
    "Comfy.DevMode": false
}
```

**Note:** These settings are not officially documented for disabling template manager but may affect startup behavior.

## Future Improvements

To properly disable the template manager, one of these would be needed:

1. **Feature Request**: Submit request to [ComfyUI GitHub](https://github.com/Comfy-Org/ComfyUI) for official setting
2. **Frontend Modification**: Modify `ComfyUI_frontend` source code (requires custom build)
3. **Custom Node**: Create extension to override template manager behavior

## Research Sources

- [ComfyUI Settings Documentation](https://docs.comfy.org/interface/settings/comfy)
- [ComfyUI Settings Wiki](https://comfyui-wiki.com/en/interface/settings/comfy)
- [ComfyUI Templates Discussion](https://github.com/comfyanonymous/ComfyUI/discussions/2159)
- [ComfyUI Frontend Repository](https://github.com/Comfy-Org/ComfyUI_frontend)
- [Menu Settings Guide](https://comfyui-wiki.com/en/interface/settings/menu)

## Related Documentation

- [DEFAULT_WORKFLOW.md](./DEFAULT_WORKFLOW.md) - Auto-load workflow configuration
- [SECURITY.md](./SECURITY.md) - Authentication and security settings
- [ComfyUI_image_provisioning.md](./ComfyUI_image_provisioning.md) - Model provisioning guide
