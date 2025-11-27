# Environment variables templates

## Flux.2 dev

```bash
CIVITAI_TOKEN="{{ RUNPOD_SECRET_CivitAI_API_KEY }}"
HF_TOKEN="{{ RUNPOD_SECRET_HF_TOKEN_WRITE }}"
PASSWORD="{{ RUNPOD_SECRET_CODE-SERVER-NEW }}"
HF_MODEL_DIFFUSION_MODELS1=Comfy-Org/flux2-dev
HF_MODEL_DIFFUSION_MODELS_FILENAME1=split_files/diffusion_models/flux2_dev_fp8mixed.safetensors
HF_MODEL_VAE1=Comfy-Org/flux2-dev
HF_MODEL_VAE_FILENAME1=split_files/vae/flux2-vae.safetensors
HF_MODEL_TEXT_ENCODERS1=Comfy-Org/flux2-dev
HF_MODEL_TEXT_ENCODERS_FILENAME1=split_files/text_encoders/mistral_3_small_flux2_fp8.safetensors
HF_MODEL_UPSCALER1=LS110824/upscale
HF_MODEL_UPSCALER_PTH1=4x_foolhardy_Remacri.pth
```

## Z-Image-Turbo

```bash
CIVITAI_TOKEN="{{ RUNPOD_SECRET_CivitAI_API_KEY }}"
HF_TOKEN="{{ RUNPOD_SECRET_HF_TOKEN_WRITE }}"
PASSWORD="{{ RUNPOD_SECRET_CODE-SERVER-NEW }}"
HF_MODEL_DIFFUSION_MODELS1=Comfy-Org/z_image_turbo
HF_MODEL_DIFFUSION_MODELS_FILENAME1=split_files/diffusion_models/z_image_turbo_bf16.safetensors
HF_MODEL_VAE1=Comfy-Org/z_image_turbo
HF_MODEL_VAE_FILENAME1=split_files/vae/ae.safetensors
HF_MODEL_TEXT_ENCODERS1=Comfy-Org/z_image_turbo
HF_MODEL_TEXT_ENCODERS_FILENAME1=split_files/text_encoders/qwen_3_4b.safetensors
HF_MODEL_UPSCALER1=LS110824/upscale
HF_MODEL_UPSCALER_PTH1=4x_foolhardy_Remacri.pth
```

## Flux.1 dev Kontext

```bash
CIVITAI_TOKEN="{{ RUNPOD_SECRET_CivitAI_API_KEY }}"
HF_TOKEN="{{ RUNPOD_SECRET_HF_TOKEN_WRITE }}"
PASSWORD="{{ RUNPOD_SECRET_CODE-SERVER-NEW }}"
HF_MODEL_DIFFUSION_MODELS1=black-forest-labs/FLUX.1-Kontext-dev
HF_MODEL_DIFFUSION_MODELS_FILENAME1=flux1-kontext-dev.safetensors
HF_MODEL_VAE1=black-forest-labs/FLUX.1-Kontext-dev
HF_MODEL_VAE_FILENAME1=ae.safetensors
HF_MODEL_TEXT_ENCODERS1=comfyanonymous/flux_text_encoders
HF_MODEL_TEXT_ENCODERS_FILENAME1=t5xxl_fp16.safetensors
HF_MODEL_UPSCALER1=LS110824/upscale
HF_MODEL_UPSCALER_PTH1=4x_foolhardy_Remacri.pth
HF_MODEL_TEXT_ENCODERS2=zer0int/CLIP-GmP-ViT-L-14
HF_MODEL_TEXT_ENCODERS_FILENAME2=ViT-L-14-TEXT-detail-improved-hiT-GmP-TE-only-HF.safetensors
```

## Flux.1 dev SRPO

```bash
CIVITAI_TOKEN="{{ RUNPOD_SECRET_CivitAI_API_KEY }}"
HF_TOKEN="{{ RUNPOD_SECRET_HF_TOKEN_WRITE }}"
PASSWORD="{{ RUNPOD_SECRET_CODE-SERVER-NEW }}"
HF_MODEL_UPSCALER1=LS110824/upscale
HF_MODEL_UPSCALER_PTH1=4x_foolhardy_Remacri.pth
HF_MODEL_DIFFUSION_MODELS1=rockerBOO/flux.1-dev-SRPO
HF_MODEL_DIFFUSION_MODELS_FILENAME1=flux.1-dev-SRPO-bf16.safetensors
HF_MODEL_TEXT_ENCODERS1=comfyanonymous/flux_text_encoders
HF_MODEL_TEXT_ENCODERS_FILENAME1=t5xxl_fp16.safetensors
HF_MODEL_TEXT_ENCODERS2=zer0int/CLIP-GmP-ViT-L-14
HF_MODEL_TEXT_ENCODERS_FILENAME2=ViT-L-14-TEXT-detail-improved-hiT-GmP-TE-only-HF.safetensors
HF_MODEL_VAE1=black-forest-labs/FLUX.1-Kontext-dev
HF_MODEL_VAE_FILENAME1=ae.safetensors
```


