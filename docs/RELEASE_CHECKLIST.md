# Release Checklist

## Pre-Release

- [ ] Pull latest `main` and verify clean working tree.
- [ ] Run local checks:
  - `./scripts/healthcheck.sh`
  - `./scripts/verify-modes.sh`
  - `./scripts/benchmark.sh` (when relevant)
- [ ] Confirm CI is passing on latest commit.
- [ ] Update docs for behavior changes.
- [ ] Update `CHANGELOG.md`.

## Versioning

- [ ] Create a version tag (for example, `v0.1.1`).
- [ ] Ensure changelog section exists for that version.

## Publish

- [ ] Create GitHub release notes from changelog.
- [ ] Include known limitations and migration notes.
- [ ] Link any benchmark snapshots if applicable.

## Post-Release

- [ ] Announce release in Discussions.
- [ ] Triage incoming bug reports and follow-ups.
