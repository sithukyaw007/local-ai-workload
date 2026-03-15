# Troubleshooting

## Quick Matrix

| Symptom | Likely Cause | What to Run |
|---|---|---|
| Gateway is unreachable | Services not running | `./scripts/start-all.sh` then `./scripts/healthcheck.sh` |
| Claude reports auth/provider errors | Local settings not applied | `./scripts/install-claude-local-settings.sh` |
| Model calls time out | Heavy model or high context settings | Lower context/model profile and retry |
| Quality model context overflow | Context too high for active model | Use `local-coder-fast` or reduce context |
| Docker model runner unavailable | Docker Desktop feature disabled | Enable Docker Model Runner in Docker Desktop settings |

## Diagnostics Checklist

1. Confirm Docker is running.
2. Run `./scripts/healthcheck.sh`.
3. Inspect `.env` for endpoint and key settings.
4. Verify gateway aliases in `config/router.yaml`.
5. Re-run `./scripts/verify-modes.sh`.

## Log Locations

- `logs/` directory for local script outputs.
- Docker service logs via `docker compose -f docker/docker-compose.yml logs`.
