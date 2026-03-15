# Local AI Workload (Docker First)

This folder provides an end-to-end control plane for local AI development and design workflows on macOS with Docker Desktop as primary runtime.

Detailed architecture and operations guide:
- SOLUTION_ARCHITECTURE.md
- OFFLINE_HYBRID_VERIFICATION.md
- CLAUDE_CODE_LOCAL_SETUP_PLAN.md

## Architecture

- Ollama for convenience model hosting.
- llama.cpp server for high-quality local coding/review tasks.
- LiteLLM gateway to expose one OpenAI-compatible endpoint.
- Optional cloud fallback disabled by default.

## Prerequisites

- macOS Apple Silicon
- Docker Desktop running
- Homebrew installed
- Setup scripts are included in this repo:
  - ./scripts/setup_docker_vllm_metal.sh
  - ./scripts/setup_ai_toolkit.sh
  - brew install llama.cpp

## Quick Start

1. Copy env file.
2. Run bootstrap.
3. Pull Ollama models.
4. Start services.
5. Run health check.
6. Run benchmark.

```bash
cd /Users/sithukyaw/work/local-ai-workload
cp .env.example .env
./scripts/bootstrap.sh
./scripts/pull-models.sh
./scripts/start-all.sh
./scripts/healthcheck.sh
./scripts/benchmark.sh
```

Gateway endpoint for Claude Code:

- Base URL for Claude (ANTHROPIC_BASE_URL): http://localhost:4000
- Base URL for OpenAI-style clients: http://localhost:4000/v1
- Example model alias: local-coder-quality
- API key: managed by scripts/claude-api-key-helper.sh (Keychain-first)

For local-coder-quality through llama.cpp, set LLAMA_MODEL_PATH in .env to an existing GGUF file.
As an alternative, set LLAMA_HF_REPO to let llama.cpp fetch a model from Hugging Face.

## Daily Operations

Start stack:

```bash
./scripts/start-all.sh
```

Stop stack:

```bash
./scripts/stop-all.sh
```

Check health:

```bash
./scripts/healthcheck.sh
```

## Notes on RAM Budget

For a 64 GB machine with 24 GB reserved for non-AI workloads:

- Keep total active AI memory near 32-36 GB.
- Run one heavy quality model at a time.
- Keep default context around 8k-16k and increase only when needed.

## Claude Code Integration

Set Claude Code to use the gateway endpoint and local aliases:

- local-coder-fast
- local-coder-quality
- local-general

Use cloud-fallback only if local output is not sufficient.

### Implemented Credential Mode (apiKeyHelper-first)

1. Seed Keychain from current gateway key:

```bash
./scripts/claude-keychain-init.sh
```

2. Install project-local Claude settings for Terminal CLI and VS Code surface:

```bash
./scripts/install-claude-local-settings.sh
```

3. Verify compatibility:

```bash
./scripts/claude-compat-check.sh
```

4. Rotate gateway key when needed (updates .env + Keychain + gateway container):

```bash
./scripts/claude-keychain-rotate.sh
```

### Formal Offline and Hybrid Verification

Run full verification for both modes in one command:

```bash
./scripts/verify-modes.sh
```

Checklist and pass criteria:

- OFFLINE_HYBRID_VERIFICATION.md

### Claude Session Preflight

Run a full preflight and Claude local-model smoke test:

```bash
./scripts/claude-preflight.sh offline
```

Use `hybrid` instead of `offline` if desired.

### Operating Modes

Set offline mode (local only):

```bash
./scripts/claude-mode.sh offline
```

Set hybrid mode (local primary with optional cloud fallback):

```bash
./scripts/claude-mode.sh hybrid
```

After mode changes, apply with:

```bash
docker compose -f docker/docker-compose.yml --env-file .env up -d --force-recreate
```
