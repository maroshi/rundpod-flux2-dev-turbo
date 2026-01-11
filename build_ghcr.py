#!/usr/bin/env python3
"""
Build and push Docker image to GitHub Container Registry (GHCR)

Usage:
    python build_ghcr.py [--tag TAG] [--no-push] [--registry REGISTRY] [--username USERNAME]

Examples:
    python build_ghcr.py                              # Build and push with auto-generated tag
    python build_ghcr.py --tag v1.0                   # Build and push with version tag
    python build_ghcr.py --tag latest                 # Build and push as latest
    python build_ghcr.py --no-push                    # Build only, don't push
    python build_ghcr.py --token-file ~/.ghcr_token   # Specify token file path

Token File:
    Default location: .ghcr_token (in parent directory, committed to repo)
    Token format: Just the PAT token value (e.g., ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx)
    Argument: Can override with --token-file /path/to/token
    Note: Keep actual token value secret when committing (use placeholder during development)

Environment Variables:
    IMAGE_TAG           - Override tag (e.g., "v1.0", "latest", "build-20260111")
    GHCR_REGISTRY       - Override registry (default: ghcr.io)
    GHCR_USERNAME       - Override username (default: maroshi)
"""

import subprocess
import os
import argparse
from datetime import datetime
from pathlib import Path

# Configuration
REGISTRY = os.environ.get("GHCR_REGISTRY", "ghcr.io")
USERNAME = os.environ.get("GHCR_USERNAME", "maroshi")
IMAGE_NAME = "flux2-turbo-lora"
DOCKERFILE_PATH = "rundpod-flux2-dev-turbo"

# Colors for output
class Colors:
    BLUE = '\033[0;34m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    NC = '\033[0m'  # No Color

def log_info(msg):
    print(f"{Colors.BLUE}[INFO]{Colors.NC} {msg}")

def log_success(msg):
    print(f"{Colors.GREEN}[✓]{Colors.NC} {msg}")

def log_warning(msg):
    print(f"{Colors.YELLOW}[WARN]{Colors.NC} {msg}")

def log_error(msg):
    print(f"{Colors.RED}[ERROR]{Colors.NC} {msg}")

def run_command(cmd, description=""):
    """Run a shell command and return success status"""
    if description:
        log_info(description)

    try:
        result = subprocess.run(cmd, check=False, capture_output=False)
        return result.returncode == 0
    except Exception as e:
        log_error(f"Failed to execute command: {e}")
        return False

def check_docker():
    """Verify Docker is installed and running"""
    try:
        subprocess.run(["docker", "info"], capture_output=True, check=True)
        log_success("Docker is available")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        log_error("Docker is not installed or not running")
        return False

def check_dockerfile():
    """Verify Dockerfile exists at specified path"""
    dockerfile = Path(DOCKERFILE_PATH) / "Dockerfile"
    if dockerfile.exists():
        log_success(f"Dockerfile found at {dockerfile}")
        return True
    else:
        log_error(f"Dockerfile not found at {dockerfile}")
        return False

def build_image(image_uri):
    """Build Docker image"""
    log_info(f"Building image: {image_uri}")
    cmd = ["docker", "build", "-t", image_uri, DOCKERFILE_PATH]

    if run_command(cmd):
        log_success(f"Image built successfully: {image_uri}")
        return True
    else:
        log_error("Docker build failed")
        return False

def push_image(image_uri):
    """Push Docker image to GHCR"""
    log_info(f"Pushing image to GHCR: {image_uri}")

    # Check if already authenticated
    cmd = ["docker", "push", image_uri]

    if run_command(cmd):
        log_success(f"Image pushed successfully: {image_uri}")
        return True
    else:
        log_error("Docker push failed")
        log_warning("Make sure you are authenticated with GHCR:")
        log_warning('  echo "$GHCR_TOKEN" | docker login ghcr.io -u maroshi --password-stdin')
        return False

def find_token_file(token_file_path=None):
    """Find and read GHCR token from file

    Token file path can be:
    1. Provided as argument (--token-file)
    2. Default location: .ghcr_token in parent directory
    """
    # Use provided path or default
    if token_file_path:
        expanded_path = os.path.expanduser(token_file_path)
    else:
        expanded_path = os.path.expanduser(".ghcr_token")

    if os.path.exists(expanded_path):
        try:
            with open(expanded_path, "r") as f:
                token = f.read().strip()
                if token:
                    log_success(f"Token file found: {expanded_path}")
                    return token
        except IOError as e:
            log_warning(f"Could not read token file {expanded_path}: {e}")

    return None

def authenticate_ghcr(token_file=None, registry=REGISTRY, username=USERNAME):
    """Authenticate with GHCR using token from file"""
    token = find_token_file(token_file)

    if not token:
        log_error("GHCR token file not found")
        log_warning("Expected token file at: .ghcr_token (in parent directory)")
        log_warning("\nAlternatively, specify custom path:")
        log_warning("  python build_ghcr.py --token-file /path/to/token")
        log_warning("\nToken file should contain just the PAT:")
        log_warning("  ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
        return False

    log_info(f"Authenticating with GHCR ({registry})...")
    cmd = f'echo "{token}" | docker login {registry} -u {username} --password-stdin'

    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, check=False)
        if result.returncode == 0:
            log_success("Successfully authenticated with GHCR")
            return True
        else:
            log_error("GHCR authentication failed")
            error_output = result.stderr.decode() if result.stderr else ""
            if error_output:
                log_warning(f"Error: {error_output}")
            return False
    except Exception as e:
        log_error(f"Authentication error: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(
        description="Build and push Docker image to GitHub Container Registry (GHCR)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python build_ghcr.py                              # Build and push with auto-generated tag
  python build_ghcr.py --tag v1.0                   # Build and push with version tag
  python build_ghcr.py --tag latest                 # Build and push as latest
  python build_ghcr.py --no-push                    # Build only, don't push
  IMAGE_TAG=v1.0 python build_ghcr.py               # Use environment variable
        """
    )

    parser.add_argument(
        "--tag",
        default=os.environ.get("IMAGE_TAG"),
        help="Image tag (default: auto-generated from timestamp)"
    )

    parser.add_argument(
        "--no-push",
        action="store_true",
        help="Build image but don't push to GHCR"
    )

    parser.add_argument(
        "--registry",
        default=REGISTRY,
        help=f"Container registry URL (default: {REGISTRY})"
    )

    parser.add_argument(
        "--username",
        default=USERNAME,
        help=f"Registry username (default: {USERNAME})"
    )

    parser.add_argument(
        "--token-file",
        default=None,
        help="Path to GHCR token file (default: searches .ghcr_token, ~/.ghcr_token, ../.ghcr_token)"
    )

    parser.add_argument(
        "--no-auth",
        action="store_true",
        help="Skip GHCR authentication (if already logged in)"
    )

    args = parser.parse_args()

    # Use provided registry and username
    registry = args.registry
    username = args.username

    # Generate tag if not provided
    tag = args.tag or f"build-{datetime.now().strftime('%Y%m%d-%H%M%S')}"

    # Build full image URI
    image_uri = f"{registry}/{username}/{IMAGE_NAME}:{tag}"

    print(f"\n{Colors.BLUE}═══════════════════════════════════════════════════════════{Colors.NC}")
    print(f"{Colors.BLUE}Docker Image Build and Push to GHCR{Colors.NC}")
    print(f"{Colors.BLUE}═══════════════════════════════════════════════════════════{Colors.NC}\n")

    log_info(f"Registry: {registry}")
    log_info(f"Username: {username}")
    log_info(f"Image: {IMAGE_NAME}")
    log_info(f"Tag: {tag}")
    log_info(f"Full URI: {image_uri}\n")

    # Pre-flight checks
    if not check_docker():
        return 1

    if not check_dockerfile():
        return 1

    # Build image
    if not build_image(image_uri):
        return 1

    print()

    # Push if requested
    if not args.no_push:
        # Authenticate if not skipped
        if not args.no_auth:
            if not authenticate_ghcr(token_file=args.token_file, registry=registry, username=username):
                log_warning("Skipping push. You can manually authenticate and push with:")
                log_warning(f"  docker push {image_uri}")
                return 1

        print()

        # Push image
        if not push_image(image_uri):
            return 1

        # Also push as latest if not already
        if tag != "latest":
            latest_uri = f"{registry}/{username}/{IMAGE_NAME}:latest"
            log_info(f"Also pushing as latest: {latest_uri}")

            tag_cmd = ["docker", "tag", image_uri, latest_uri]
            push_cmd = ["docker", "push", latest_uri]

            if subprocess.run(tag_cmd).returncode == 0 and subprocess.run(push_cmd).returncode == 0:
                log_success(f"Successfully pushed latest tag: {latest_uri}")
            else:
                log_warning("Could not push latest tag")

    print(f"\n{Colors.BLUE}═══════════════════════════════════════════════════════════{Colors.NC}")
    print(f"{Colors.GREEN}✓ Build complete!{Colors.NC}")
    print(f"{Colors.BLUE}═══════════════════════════════════════════════════════════{Colors.NC}\n")

    log_info(f"Image built: {image_uri}")

    if not args.no_push:
        log_success(f"Image pushed to GHCR: {registry}/{username}/{IMAGE_NAME}")
        log_info(f"Pull with: docker pull {image_uri}")
    else:
        log_info("Use 'docker push' to upload the image manually:")
        log_info(f"  docker push {image_uri}")

    print()

    return 0

if __name__ == "__main__":
    exit(main())
