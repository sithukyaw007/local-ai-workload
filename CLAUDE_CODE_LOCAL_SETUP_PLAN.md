# Claude Code in Local AI Workload: Step-by-Step Plan

This guide explains how to install and use Claude Code with the current local-ai-workload stack for:

- local AI development workflows
- AI agent workflows
- offline and hybrid operation modes

## Current Status (From This Workspace)

- Local gateway and model routes are already configured.
- Project Claude settings are already present at `.claude/settings.local.json`.
- Claude CLI is not installed yet (`claude` command not found).

## Architecture Path

Claude Code -> local gateway -> local models

- Claude base URL: `http://localhost:4000`
- Anthropic-style endpoint validated: `/v1/messages`
- Key handling: `apiKeyHelper` script (Keychain-first)

## Phase 1: Install Claude Code CLI

1. Install via Homebrew (recommended on macOS):

```bash
brew install --cask claude-code
```

2. Verify install:

```bash
claude --version
```

3. If not found, add local bin path:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
claude --version
```

## Phase 2: Prepare Local Stack and Credentials

1. Start local workload stack:

```bash
cd /Users/sithukyaw/work/local-ai-workload
./scripts/start-all.sh
```

2. Initialize Keychain-backed local gateway key:

```bash
./scripts/claude-keychain-init.sh
```

3. Install project-local Claude settings:

```bash
./scripts/install-claude-local-settings.sh
```

4. Validate Claude-protocol compatibility:

```bash
./scripts/claude-compat-check.sh
```

5. Run health checks:

```bash
./scripts/healthcheck.sh
```

## Phase 3: First Claude Code Session (Local-Only)

1. Switch to offline mode (recommended for first run):

```bash
./scripts/claude-mode.sh offline
docker compose -f docker/docker-compose.yml --env-file .env up -d --force-recreate
```

2. Start Claude Code in project:

```bash
claude
```

3. In Claude Code, run `/status` and confirm:

- `apiKeyHelper` active
- `ANTHROPIC_BASE_URL=http://localhost:4000`
- model default `local-coder-quality`

## Phase 4: Daily Development Workflow (Local AI)

Use this routine each day:

1. Start stack:

```bash
./scripts/start-all.sh
./scripts/healthcheck.sh
```

2. Open Claude in project:

```bash
claude
```

3. Development loop:

- ask for plan
- implement edits
- run tests/lint
- review and refine

4. End session:

```bash
./scripts/stop-all.sh
```

## Phase 5: Agent Use Cases (Practical)

### Use Case A: Feature Implementation Agent

Prompt pattern:

- Analyze current module boundaries first.
- Propose minimal-change implementation plan.
- Apply edits and run tests.
- Return risk summary and rollback notes.

Model recommendation: `local-coder-quality`.

### Use Case B: Code Review Agent

Prompt pattern:

- Review staged changes.
- Report findings by severity.
- Suggest concrete patch-level fixes.
- Add missing tests.

Model recommendation: `local-coder-quality`.

### Use Case C: Design/Architecture Brainstorm Agent

Prompt pattern:

- Generate 2-3 architecture options.
- Compare constraints, cost, and risk.
- Recommend one with migration steps.

Model recommendation: `local-general` for ideation, then switch back to `local-coder-quality` for implementation.

### Use Case D: Refactor Safety Agent

Prompt pattern:

- Identify behavior-preserving refactor seams.
- Create sequence of small commits.
- Verify with targeted tests after each step.

Model recommendation: `local-coder-quality`.

## Phase 6: Offline vs Hybrid Operations

### Offline mode (strict local)

```bash
./scripts/claude-mode.sh offline
docker compose -f docker/docker-compose.yml --env-file .env up -d --force-recreate
```

Expected:

- local routes only
- no cloud fallback

### Hybrid mode (local-first + optional fallback)

```bash
./scripts/claude-mode.sh hybrid
docker compose -f docker/docker-compose.yml --env-file .env up -d --force-recreate
```

Expected:

- local routes remain primary
- cloud fallback only when configured and available

## Phase 7: Formal Verification and Regression Guard

Run one-command verification for both modes:

```bash
./scripts/verify-modes.sh
```

Expected result:

- `RESULT: PASS`
- log artifact in `logs/mode-verification-*.log`

## Security and Key Hygiene

1. Keep Keychain as primary key source.
2. Rotate gateway key periodically:

```bash
./scripts/claude-keychain-rotate.sh
./scripts/healthcheck.sh
```

3. Treat static key as break-glass recovery only.

## Troubleshooting Quick List

1. `claude: command not found`
- install via brew and verify PATH.

2. Claude cannot connect to local gateway
- run `./scripts/claude-compat-check.sh`
- confirm gateway is healthy.

3. Local quality model unavailable
- check llama server health and startup logs.

4. Hybrid cloud check skipped
- set `CLOUD_API_KEY` in `.env` if cloud fallback is desired.

## Recommended Rollout Order

1. Install Claude CLI.
2. Validate local integration offline first.
3. Run daily development workflows for one week on local-only.
4. Enable hybrid mode only if needed.
5. Add periodic `verify-modes` check to your maintenance routine.
