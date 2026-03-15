# Contributing

Thanks for contributing to local-ai-workload.

## Development Principles

- Keep the project self-contained under this repository.
- Prefer small, focused changes and descriptive commit messages.
- Preserve offline-first behavior unless a change explicitly targets hybrid mode.
- Avoid committing secrets or machine-specific config.

## Local Setup

1. Copy env template:

```bash
cp .env.example .env
```

2. Bootstrap prerequisites:

```bash
./scripts/bootstrap.sh
```

3. Start services and verify:

```bash
./scripts/start-all.sh
./scripts/healthcheck.sh
```

## Branch and Commit Guidelines

- Branch naming examples:
  - feat/<short-description>
  - fix/<short-description>
  - docs/<short-description>
- Use Conventional Commits when possible:
  - feat: add new capability
  - fix: resolve bug
  - docs: documentation-only changes
  - chore: maintenance updates

## Pull Request Checklist

- [ ] Change is scoped and documented.
- [ ] Scripts remain executable where required.
- [ ] `./scripts/healthcheck.sh` passes locally.
- [ ] No secrets are introduced (`.env`, logs, local settings remain untracked).
- [ ] README or docs updated when behavior changes.

## Security and Secrets

- Never commit `.env`.
- Never commit keychain exports, API keys, or personal tokens.
- If a key is exposed, rotate immediately and update local credentials using existing scripts.

## Reporting Issues

Please use the issue templates in `.github/ISSUE_TEMPLATE` and include exact repro steps and environment details.

## Questions and Support

For setup help, usage questions, or architecture discussion, use GitHub Discussions:

- https://github.com/sithukyaw007/local-ai-workload/discussions

Discussion templates are available for:

- Q&A
- Ideas
- Show and tell
