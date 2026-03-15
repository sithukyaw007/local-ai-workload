# Offline and Hybrid Verification Checklist

This checklist validates Claude Code continuity across both operating modes:

- Offline mode: local routes only
- Hybrid mode: local primary with optional cloud fallback

## Preconditions

1. Stack started:

```bash
./scripts/start-all.sh
```

2. Keychain and Claude local settings installed:

```bash
./scripts/claude-keychain-init.sh
./scripts/install-claude-local-settings.sh
```

3. Base compatibility passes:

```bash
./scripts/claude-compat-check.sh
```

## One-command execution

Run all checks for both modes and write a timestamped log:

```bash
./scripts/verify-modes.sh
```

## Pass Criteria

For each mode (`offline`, `hybrid`):

1. Mode flags are correctly written in `.env`
- `offline` => `ENABLE_CLOUD_FALLBACK=false`, `CLAUDE_OFFLINE_MODE=true`
- `hybrid` => `ENABLE_CLOUD_FALLBACK=true`, `CLAUDE_OFFLINE_MODE=false`

2. Gateway is recreated and healthy
- `GET /health/liveliness` returns 200
- `GET /v1/models` returns 200 with gateway key auth
- `POST /v1/messages` returns 200 with `x-api-key`

3. Local quality route works
- Anthropic-style call to `local-coder-quality` succeeds

4. Local general route works
- OpenAI-style call to `local-general` succeeds

5. Optional cloud fallback check (hybrid only)
- If `CLOUD_API_KEY` is set, `cloud-fallback` call should succeed
- If `CLOUD_API_KEY` is not set, check is reported as skipped (not failed)

## Expected Artifacts

1. Log file under `logs/`:
- `logs/mode-verification-YYYYMMDD-HHMMSS.log`

2. Final result line:
- `RESULT: PASS` or `RESULT: FAIL`

## Troubleshooting

1. `Gateway anthropic messages` fails:
- Run `./scripts/claude-compat-check.sh`
- Confirm `LITELLM_MASTER_KEY` in `.env`
- Confirm gateway container recreated after mode switch

2. Local quality route fails:
- Confirm llama-server is healthy:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/health
```

3. Hybrid cloud check fails:
- If intended, set `CLOUD_API_KEY` and recreate gateway:

```bash
docker compose -f docker/docker-compose.yml --env-file .env up -d --force-recreate
```

4. Restore preferred mode after testing:

```bash
./scripts/claude-mode.sh offline
# or
./scripts/claude-mode.sh hybrid
```
