#!/bin/bash
set -e

echo "============================================"
echo " AI Dev Toolkit Installation Script"
echo " For macOS Apple Silicon (M-series)"
echo "============================================"
echo ""

# -------------------------------------------
# Step 1: Prerequisites
# -------------------------------------------
echo "[1/5] Checking prerequisites..."

if ! command -v brew &>/dev/null; then
    echo "ERROR: Homebrew is not installed. Install it from https://brew.sh"
    exit 1
fi
echo "  ✓ Homebrew found"

if ! command -v docker &>/dev/null; then
    echo "ERROR: Docker is not available. Install Docker Desktop first."
    exit 1
fi
echo "  ✓ Docker found"

# -------------------------------------------
# Step 2: Install Ollama
# -------------------------------------------
echo ""
echo "[2/5] Installing Ollama..."

if command -v ollama &>/dev/null; then
    echo "  ✓ Ollama is already installed ($(ollama --version))"
else
    brew install ollama
    echo "  ✓ Ollama installed"
fi

# Start Ollama service
if brew services list | grep -q "ollama.*started"; then
    echo "  ✓ Ollama service is already running"
else
    echo "  Starting Ollama service..."
    brew services start ollama
    echo "  ✓ Ollama service started"
fi

# -------------------------------------------
# Step 3: Install uv (fast Python package manager)
# -------------------------------------------
echo ""
echo "[3/5] Installing uv..."

if command -v uv &>/dev/null; then
    echo "  ✓ uv is already installed ($(uv --version))"
else
    brew install uv
    echo "  ✓ uv installed"
fi

# -------------------------------------------
# Step 4: Install Hugging Face CLI
# -------------------------------------------
echo ""
echo "[4/5] Installing Hugging Face CLI..."

if command -v hf &>/dev/null; then
    echo "  ✓ Hugging Face CLI is already installed (hf $(hf version))"
else
    uv tool install 'huggingface-hub'
    uv tool update-shell
    echo "  ✓ Hugging Face CLI installed"
    echo "  Note: Restart your shell or run 'source ~/.zshenv' to use the 'hf' command."
fi

# -------------------------------------------
# Step 5: Install Open WebUI (via Docker)
# -------------------------------------------
echo ""
echo "[5/5] Installing Open WebUI..."

if docker ps --format '{{.Names}}' | grep -q "^open-webui$"; then
    echo "  ✓ Open WebUI container is already running"
else
    # Remove stopped container if it exists
    docker rm -f open-webui 2>/dev/null || true

    docker run -d \
        -p 3000:8080 \
        --add-host=host.docker.internal:host-gateway \
        --name open-webui \
        --restart always \
        -v open-webui:/app/backend/data \
        ghcr.io/open-webui/open-webui:main

    echo "  ✓ Open WebUI started"
fi

# -------------------------------------------
# Summary
# -------------------------------------------
echo ""
echo "============================================"
echo " Installation Complete!"
echo "============================================"
echo ""
echo " Ollama:          brew services start ollama"
echo "                  ollama run llama3.2"
echo ""
echo " uv:              uv --help"
echo ""
echo " Hugging Face:    hf --help"
echo "                  hf download <model-repo>"
echo ""
echo " Open WebUI:      http://localhost:3000"
echo "                  (Create an account on first visit)"
echo ""
echo "============================================"
