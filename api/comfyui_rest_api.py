#!/usr/bin/env python3
"""
ComfyUI REST API Wrapper for Flux.2 Turbo LoRA
Provides HTTP endpoints for automated image generation and workflow control

Endpoints:
  POST   /api/generate       - Generate image from text prompt
  GET    /api/status         - Check generation status and queue
  DELETE /api/queue/{id}     - Cancel specific job
  POST   /api/queue/clear    - Clear entire queue
  GET    /api/history        - Get generation history
  GET    /api/image/{filename} - Download generated image
"""

import json
import os
import sys
import time
import uuid
import requests
import asyncio
import websocket
from pathlib import Path
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict
from datetime import datetime
from flask import Flask, request, jsonify, send_file, send_from_directory
from flask_cors import CORS
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ============================================================================
# Configuration
# ============================================================================

COMFYUI_HOST = os.environ.get('COMFYUI_HOST', 'localhost')
COMFYUI_PORT = int(os.environ.get('COMFYUI_PORT', 8188))
API_HOST = os.environ.get('API_HOST', '0.0.0.0')
API_PORT = int(os.environ.get('API_PORT', 5000))
WORKSPACE_PATH = Path(os.environ.get('WORKSPACE_PATH', '/workspace'))
OUTPUT_DIR = WORKSPACE_PATH / 'ComfyUI' / 'output'
WORKFLOWS_DIR = Path(__file__).parent.parent / 'workflows'

COMFYUI_API_URL = f'http://{COMFYUI_HOST}:{COMFYUI_PORT}'

# ============================================================================
# Data Models
# ============================================================================

@dataclass
class GenerationRequest:
    """Image generation request"""
    prompt: str
    negative_prompt: str = ""
    steps: int = 25
    cfg: float = 3.5
    width: int = 1024
    height: int = 1024
    lora_strength: float = 1.0
    seed: int = None
    sampler: str = "euler_ancestral"
    scheduler: str = "karras"
    batch_size: int = 1

    def __post_init__(self):
        if self.seed is None:
            self.seed = int(time.time() * 1000) % 2**32


@dataclass
class GenerationStatus:
    """Status of a generation job"""
    job_id: str
    status: str  # queued, processing, completed, failed
    prompt: str
    progress: float = 0.0
    current_step: int = 0
    total_steps: int = 0
    output_image: Optional[str] = None
    error: Optional[str] = None
    created_at: str = None
    completed_at: Optional[str] = None

    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.now().isoformat()


# ============================================================================
# ComfyUI API Client
# ============================================================================

class ComfyUIClient:
    """Client for ComfyUI API"""

    def __init__(self, base_url: str):
        self.base_url = base_url
        self.session = requests.Session()
        self.queue = {}
        self.history = {}

    def load_workflow(self, workflow_name: str = 'flux2_turbo_default') -> Dict:
        """Load workflow from JSON file"""
        workflow_path = WORKFLOWS_DIR / f'{workflow_name}.json'
        if not workflow_path.exists():
            raise FileNotFoundError(f'Workflow not found: {workflow_path}')

        with open(workflow_path, 'r') as f:
            return json.load(f)

    def prepare_workflow(
        self,
        prompt: str,
        negative_prompt: str = "",
        steps: int = 25,
        cfg: float = 3.5,
        width: int = 1024,
        height: int = 1024,
        lora_strength: float = 1.0,
        seed: int = None,
        sampler: str = "euler_ancestral",
        scheduler: str = "karras"
    ) -> Dict:
        """Prepare workflow with user parameters"""
        workflow = self.load_workflow()

        # Update image dimensions (node 8: EmptyLatentImage)
        workflow['8']['inputs']['width'] = width
        workflow['8']['inputs']['height'] = height

        # Update positive prompt (node 3: CLIPTextEncode positive)
        workflow['3']['inputs']['text'] = prompt

        # Update negative prompt (node 4: CLIPTextEncode negative)
        workflow['4']['inputs']['text'] = negative_prompt

        # Update KSampler parameters (node 5)
        workflow['5']['inputs']['steps'] = steps
        workflow['5']['inputs']['cfg'] = cfg
        workflow['5']['inputs']['seed'] = seed or int(time.time() * 1000) % 2**32
        workflow['5']['inputs']['sampler_name'] = sampler
        workflow['5']['inputs']['scheduler'] = scheduler

        # Update LoRA strength (node 2: LoraLoader)
        workflow['2']['inputs']['strength_model'] = lora_strength
        workflow['2']['inputs']['strength_clip'] = lora_strength * 0.9

        return workflow

    def submit_workflow(self, workflow: Dict, client_id: str = None) -> str:
        """Submit workflow to ComfyUI queue"""
        if client_id is None:
            client_id = str(uuid.uuid4())

        payload = {
            'prompt': workflow,
            'client_id': client_id
        }

        response = self.session.post(
            f'{self.base_url}/prompt',
            json=payload
        )
        response.raise_for_status()

        result = response.json()
        prompt_id = result.get('prompt_id')

        logger.info(f'Workflow submitted: {prompt_id}')
        return prompt_id

    def get_queue(self) -> Dict:
        """Get current queue status"""
        response = self.session.get(f'{self.base_url}/queue')
        response.raise_for_status()
        return response.json()

    def get_history(self, prompt_id: str = None) -> Dict:
        """Get execution history"""
        if prompt_id:
            response = self.session.get(f'{self.base_url}/history/{prompt_id}')
        else:
            response = self.session.get(f'{self.base_url}/history')

        response.raise_for_status()
        return response.json()

    def get_system_stats(self) -> Dict:
        """Get system statistics"""
        response = self.session.get(f'{self.base_url}/system')
        response.raise_for_status()
        return response.json()

    def cancel_queue_item(self, item_id: str) -> bool:
        """Cancel a queued item"""
        response = self.session.post(
            f'{self.base_url}/interrupt',
            json={}
        )
        return response.status_code == 200

    def clear_queue(self) -> bool:
        """Clear the entire queue"""
        response = self.session.post(
            f'{self.base_url}/queue',
            json={'clear': True}
        )
        return response.status_code == 200


# ============================================================================
# Flask REST API
# ============================================================================

app = Flask(__name__)
CORS(app)

# Initialize ComfyUI client
try:
    comfyui = ComfyUIClient(COMFYUI_API_URL)
    logger.info(f'Connected to ComfyUI at {COMFYUI_API_URL}')
except Exception as e:
    logger.error(f'Failed to connect to ComfyUI: {e}')
    comfyui = None

# In-memory job tracking (replace with database for production)
jobs: Dict[str, GenerationStatus] = {}


# ============================================================================
# API Endpoints
# ============================================================================

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    try:
        if comfyui:
            stats = comfyui.get_system_stats()
            return jsonify({
                'status': 'healthy',
                'comfyui': 'connected',
                'output_dir': str(OUTPUT_DIR),
                'system': stats
            })
    except Exception as e:
        logger.error(f'Health check failed: {e}')

    return jsonify({
        'status': 'unhealthy',
        'error': 'ComfyUI not responding'
    }), 503


@app.route('/api/generate', methods=['POST'])
def generate_image():
    """
    Generate image from text prompt

    Request JSON:
    {
        "prompt": "a beautiful landscape",
        "negative_prompt": "",
        "steps": 25,
        "cfg": 3.5,
        "width": 1024,
        "height": 1024,
        "lora_strength": 1.0,
        "seed": 12345,
        "sampler": "euler_ancestral",
        "scheduler": "karras",
        "batch_size": 1
    }

    Response:
    {
        "job_id": "uuid",
        "status": "queued",
        "prompt": "a beautiful landscape",
        "message": "Image generation queued"
    }
    """
    if not comfyui:
        return jsonify({'error': 'ComfyUI not connected'}), 503

    try:
        data = request.get_json()

        # Validate required fields
        if not data.get('prompt'):
            return jsonify({'error': 'Missing required field: prompt'}), 400

        # Create generation request
        gen_request = GenerationRequest(
            prompt=data['prompt'],
            negative_prompt=data.get('negative_prompt', ''),
            steps=int(data.get('steps', 25)),
            cfg=float(data.get('cfg', 3.5)),
            width=int(data.get('width', 1024)),
            height=int(data.get('height', 1024)),
            lora_strength=float(data.get('lora_strength', 1.0)),
            seed=data.get('seed'),
            sampler=data.get('sampler', 'euler_ancestral'),
            scheduler=data.get('scheduler', 'karras'),
            batch_size=int(data.get('batch_size', 1))
        )

        # Prepare workflow
        workflow = comfyui.prepare_workflow(
            prompt=gen_request.prompt,
            negative_prompt=gen_request.negative_prompt,
            steps=gen_request.steps,
            cfg=gen_request.cfg,
            width=gen_request.width,
            height=gen_request.height,
            lora_strength=gen_request.lora_strength,
            seed=gen_request.seed,
            sampler=gen_request.sampler,
            scheduler=gen_request.scheduler
        )

        # Submit to ComfyUI
        job_id = str(uuid.uuid4())
        prompt_id = comfyui.submit_workflow(workflow, client_id=job_id)

        # Track job
        status = GenerationStatus(
            job_id=job_id,
            status='queued',
            prompt=gen_request.prompt,
            total_steps=gen_request.steps
        )
        jobs[job_id] = status

        logger.info(f'Generated job {job_id}: {gen_request.prompt}')

        return jsonify({
            'job_id': job_id,
            'prompt_id': prompt_id,
            'status': 'queued',
            'prompt': gen_request.prompt,
            'message': 'Image generation queued'
        }), 202

    except Exception as e:
        logger.error(f'Generation error: {e}', exc_info=True)
        return jsonify({'error': str(e)}), 500


@app.route('/api/status/<job_id>', methods=['GET'])
def get_status(job_id):
    """
    Get generation status

    Response:
    {
        "job_id": "uuid",
        "status": "processing",
        "prompt": "a beautiful landscape",
        "progress": 0.45,
        "current_step": 11,
        "total_steps": 25,
        "output_image": null,
        "error": null
    }
    """
    if job_id not in jobs:
        return jsonify({'error': 'Job not found'}), 404

    status = jobs[job_id]

    # Fetch latest from ComfyUI history
    try:
        if status.status == 'queued' or status.status == 'processing':
            history = comfyui.get_history(job_id)
            if history:
                logger.info(f'Updated status for {job_id}')
    except Exception as e:
        logger.warning(f'Could not fetch history: {e}')

    return jsonify(asdict(status)), 200


@app.route('/api/queue', methods=['GET'])
def get_queue():
    """
    Get queue status

    Response:
    {
        "queue_pending": [...],
        "queue_running": [...],
        "jobs": {...}
    }
    """
    try:
        queue_status = comfyui.get_queue()
        return jsonify({
            'queue': queue_status,
            'jobs': {job_id: asdict(status) for job_id, status in jobs.items()},
            'total_jobs': len(jobs)
        }), 200
    except Exception as e:
        logger.error(f'Queue fetch error: {e}')
        return jsonify({'error': str(e)}), 500


@app.route('/api/queue/clear', methods=['POST'])
def clear_queue():
    """Clear entire queue"""
    try:
        result = comfyui.clear_queue()
        jobs.clear()
        return jsonify({
            'status': 'success' if result else 'failed',
            'message': 'Queue cleared'
        }), 200
    except Exception as e:
        logger.error(f'Clear queue error: {e}')
        return jsonify({'error': str(e)}), 500


@app.route('/api/queue/<job_id>', methods=['DELETE'])
def cancel_job(job_id):
    """Cancel a specific job"""
    if job_id not in jobs:
        return jsonify({'error': 'Job not found'}), 404

    try:
        comfyui.cancel_queue_item(job_id)
        jobs[job_id].status = 'cancelled'
        return jsonify({
            'status': 'success',
            'message': f'Job {job_id} cancelled'
        }), 200
    except Exception as e:
        logger.error(f'Cancel error: {e}')
        return jsonify({'error': str(e)}), 500


@app.route('/api/history', methods=['GET'])
def get_history():
    """Get generation history"""
    try:
        history = comfyui.get_history()
        return jsonify({
            'history': history,
            'total_items': len(history)
        }), 200
    except Exception as e:
        logger.error(f'History fetch error: {e}')
        return jsonify({'error': str(e)}), 500


@app.route('/api/image/<filename>', methods=['GET'])
def download_image(filename):
    """Download generated image"""
    try:
        file_path = OUTPUT_DIR / filename
        if not file_path.exists():
            return jsonify({'error': 'Image not found'}), 404

        return send_file(
            file_path,
            mimetype='image/png',
            as_attachment=True,
            download_name=filename
        )
    except Exception as e:
        logger.error(f'Download error: {e}')
        return jsonify({'error': str(e)}), 500


@app.route('/api/outputs', methods=['GET'])
def list_outputs():
    """List all generated images"""
    try:
        if not OUTPUT_DIR.exists():
            return jsonify({'images': [], 'total': 0}), 200

        images = [f.name for f in OUTPUT_DIR.glob('*.png')]
        return jsonify({
            'images': sorted(images, reverse=True),
            'total': len(images),
            'output_dir': str(OUTPUT_DIR)
        }), 200
    except Exception as e:
        logger.error(f'List outputs error: {e}')
        return jsonify({'error': str(e)}), 500


@app.route('/api/workflows', methods=['GET'])
def list_workflows():
    """List available workflows"""
    try:
        workflows = [f.stem for f in WORKFLOWS_DIR.glob('*.json')]
        return jsonify({
            'workflows': workflows,
            'total': len(workflows)
        }), 200
    except Exception as e:
        logger.error(f'List workflows error: {e}')
        return jsonify({'error': str(e)}), 500


@app.route('/api/system', methods=['GET'])
def get_system():
    """Get system information"""
    try:
        stats = comfyui.get_system_stats()
        return jsonify(stats), 200
    except Exception as e:
        logger.error(f'System stats error: {e}')
        return jsonify({'error': str(e)}), 500


# ============================================================================
# Initialization & Main
# ============================================================================

def initialize_directories():
    """Ensure required directories exist"""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    WORKFLOWS_DIR.mkdir(parents=True, exist_ok=True)
    logger.info(f'Output directory: {OUTPUT_DIR}')
    logger.info(f'Workflows directory: {WORKFLOWS_DIR}')


if __name__ == '__main__':
    initialize_directories()

    logger.info(f'Starting REST API on {API_HOST}:{API_PORT}')
    logger.info(f'ComfyUI endpoint: {COMFYUI_API_URL}')

    app.run(
        host=API_HOST,
        port=API_PORT,
        debug=os.environ.get('DEBUG', 'false').lower() == 'true'
    )
