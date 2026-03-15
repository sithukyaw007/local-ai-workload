# llama.cpp (Homebrew) end-to-end setup

This folder provides a full setup flow for running `llama.cpp` on macOS using Homebrew, without building from source.

## Folder layout

- `scripts/install.sh` Install and verify `llama.cpp`
- `scripts/run-cli.sh` Run interactive terminal chat (`llama-cli`)
- `scripts/start-server.sh` Start OpenAI-compatible local API server (`llama-server`)
- `scripts/healthcheck.sh` Check server health endpoint
- `scripts/stop-server.sh` Stop background server process
- `.env.example` Runtime defaults

## Quick start

1. Open terminal in this folder:

```bash
cd /Users/sithukyaw/work/local-ai-workload/llama-cpp-brew
```

2. Install and verify:

```bash
./scripts/install.sh
```

3. Optional: customize runtime/model settings:

```bash
cp .env.example .env
# edit .env as needed
```

4. Run interactive chat in terminal:

```bash
./scripts/run-cli.sh
```

5. Or run API server in background:

```bash
./scripts/start-server.sh
./scripts/healthcheck.sh
```

6. Stop server:

```bash
./scripts/stop-server.sh
```

## Model selection

Set one of these in `.env`:

- `LLAMA_MODEL_PATH=/absolute/path/to/model.gguf`
- `LLAMA_HF_REPO=user/model-GGUF:Q4_K_M` (used when `LLAMA_MODEL_PATH` is empty)

Default HF model:

- `bartowski/Qwen2.5-0.5B-Instruct-GGUF:Q4_K_M`

## Notes

- `-ngl 999` is used by default to offload layers to Metal GPU when possible.
- Server logs are written to `/tmp/llama-cpp-server.log`.
- PID file is written to `.llama-server.pid`.
