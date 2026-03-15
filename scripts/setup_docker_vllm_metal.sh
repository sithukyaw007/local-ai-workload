#!/bin/bash
set -e

echo "============================================"
echo " Docker vLLM-Metal Setup Script"
echo " For macOS Apple Silicon (M-series)"
echo "============================================"
echo ""

# -------------------------------------------
# Step 1: Prerequisites
# -------------------------------------------
echo "[1/5] Checking prerequisites..."

# Check macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ERROR: This script requires macOS."
    exit 1
fi
echo "  ✓ macOS $(sw_vers -productVersion)"

# Check Apple Silicon
CHIP=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || true)
if [[ "$CHIP" != *"Apple M"* ]]; then
    echo "ERROR: Apple Silicon (M-series) is required. Detected: $CHIP"
    exit 1
fi
echo "  ✓ $CHIP"

# Check Metal GPU support
if ! system_profiler SPDisplaysDataType 2>/dev/null | grep -q "Metal Support"; then
    echo "ERROR: Metal GPU support not detected."
    exit 1
fi
echo "  ✓ Metal GPU available"

# -------------------------------------------
# Step 2: Check Docker Desktop
# -------------------------------------------
echo ""
echo "[2/5] Checking Docker Desktop..."

if ! command -v docker &>/dev/null; then
    echo "ERROR: Docker is not installed."
    echo "  Install Docker Desktop from https://www.docker.com/products/docker-desktop/"
    echo "  Or via: brew install --cask docker"
    exit 1
fi

# Switch to Docker Desktop context (required for Model Runner)
CURRENT_CONTEXT=$(docker context show 2>/dev/null || true)
if [[ "$CURRENT_CONTEXT" != "desktop-linux" ]]; then
    if docker context ls --format '{{.Name}}' | grep -q "^desktop-linux$"; then
        echo "  Switching Docker context from '$CURRENT_CONTEXT' to 'desktop-linux'..."
        docker context use desktop-linux
        echo "  ✓ Docker context switched to desktop-linux"
    else
        echo "ERROR: Docker Desktop context 'desktop-linux' not found."
        echo "  Ensure Docker Desktop is installed and has been started at least once."
        exit 1
    fi
else
    echo "  ✓ Docker context is already 'desktop-linux'"
fi

# Verify Docker Desktop version (need 4.62+)
DD_VERSION=$(docker version --format '{{.Server.Platform.Name}}' 2>/dev/null || true)
if [[ -z "$DD_VERSION" ]]; then
    echo "ERROR: Cannot connect to Docker Desktop. Ensure it is running."
    exit 1
fi
echo "  ✓ $DD_VERSION"

# -------------------------------------------
# Step 3: Check Docker Model Runner
# -------------------------------------------
echo ""
echo "[3/5] Checking Docker Model Runner..."

if ! docker model status &>/dev/null; then
    echo "ERROR: Docker Model Runner is not available."
    echo "  Enable it in Docker Desktop → Settings → Features in development → Enable Docker Model Runner"
    exit 1
fi
echo "  ✓ Docker Model Runner is running"

# -------------------------------------------
# Step 4: Install vllm-metal backend
# -------------------------------------------
echo ""
echo "[4/5] Installing vllm-metal backend..."

VLLM_STATUS=$(docker model status 2>/dev/null | grep "^vllm" || true)
if echo "$VLLM_STATUS" | grep -q "Running"; then
    echo "  ✓ vllm-metal backend is already installed and running"
else
    docker model install-runner --backend vllm
    echo "  ✓ vllm-metal backend installed"
fi

# Verify
docker model status 2>/dev/null | grep "^vllm"

# -------------------------------------------
# Step 5: Pull and test a model
# -------------------------------------------
echo ""
echo "[5/5] Pulling test model..."

TEST_MODEL="hf.co/mlx-community/Llama-3.2-1B-Instruct-4bit"

# Check if already pulled
if docker model list 2>/dev/null | grep -q "llama-3.2-1b-instruct-4bit"; then
    echo "  ✓ Test model already pulled"
else
    docker model pull "$TEST_MODEL"
    echo "  ✓ Test model pulled"
fi

# Quick inference test
echo ""
echo "Running inference test..."
docker model run "$TEST_MODEL" "Say hello in exactly 5 words."
echo ""

echo "============================================"
echo " Setup Complete!"
echo "============================================"
echo ""
echo "vllm-metal backend is running with Docker Model Runner."
echo ""
echo "Usage:"
echo "  docker model pull hf.co/mlx-community/<model-name>   # Pull an MLX model"
echo "  docker model run <model> \"<prompt>\"                   # Run inference"
echo "  docker model ps                                       # List running models"
echo "  docker model status                                   # Check backend status"
echo "  docker model list                                     # List pulled models"
echo ""
echo "Recommended models for your system:"
echo "  hf.co/mlx-community/Llama-3.2-1B-Instruct-4bit       # ~700MB, fast testing"
echo "  hf.co/mlx-community/Mistral-7B-Instruct-v0.3-4bit    # ~4GB, general purpose"
echo "  hf.co/mlx-community/Qwen3-Coder-Next-4bit            # Coding-focused"
echo ""
echo "API endpoint: http://localhost:12434/v1 (OpenAI-compatible)"
echo ""
echo "Note: Docker context is now set to 'desktop-linux'."
echo "  To switch back to another context: docker context use <context-name>"
