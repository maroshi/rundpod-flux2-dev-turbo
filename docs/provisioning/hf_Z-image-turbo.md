# Manual provisioning Z-Image

- [HF ComfyUI](https://huggingface.co/Comfy-Org/z_image_turbo/tree/main)

## Diffusion_model

### bf16

```bash
hf download Comfy-Org/z_image_turbo split_files/diffusion_models/z_image_turbo_bf16.safetensors \
--local-dir /workspace/ComfyUI/models/diffusion_models/
``` 
## CLIP Text encoder

```bash
hf download Comfy-Org/z_image_turbo split_files/text_encoders/qwen_3_4b.safetensors \
--local-dir /workspace/ComfyUI/models/text_encoders/
```
## Vae

```bash
hf download Comfy-Org/z_image_turbo split_files/vae/ae.safetensors \
--local-dir /workspace/ComfyUI/models/vae/
```



