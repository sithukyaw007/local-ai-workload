# Architecture

This project provides a local-first AI control plane for software and design workloads.

## Goals

- Keep workflows local and private by default.
- Provide one stable gateway endpoint for clients.
- Allow optional hybrid fallback when local quality is not enough.

## Runtime Components

- Ollama: fast local model host for convenience tasks.
- llama.cpp server: quality local model host for coding and review tasks.
- LiteLLM gateway: unified API surface and model alias routing.
- Open WebUI: optional browser interface.

## Request Flow

1. Client targets gateway at `http://localhost:4000`.
2. Gateway routes by model alias from `config/router.yaml`.
3. Backend runtime handles inference.
4. Response is returned through gateway to the client.

## Modes

- Offline mode: all traffic remains local.
- Hybrid mode: local-first with optional cloud fallback.

## Key Configuration

- `.env`: runtime flags and endpoint settings.
- `config/router.yaml`: alias and backend routing.
- `config/profiles.yaml`: usage profiles.
- `docker/docker-compose.yml`: service composition.

## Operational Scripts

- `scripts/bootstrap.sh`: prerequisites and setup flow.
- `scripts/start-all.sh`: start local services.
- `scripts/healthcheck.sh`: service verification.
- `scripts/verify-modes.sh`: offline/hybrid validation.
