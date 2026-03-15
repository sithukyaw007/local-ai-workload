# Benchmark Methodology

## Purpose

Provide transparent and repeatable measurements for latency and quality-oriented workflows.

## Baseline Procedure

1. Start services with `./scripts/start-all.sh`.
2. Verify health with `./scripts/healthcheck.sh`.
3. Run `./scripts/benchmark.sh`.
4. Record command output and environment summary.

## Inputs

- Prompt sets in `benchmarks/`.
- Runtime settings from `.env`.
- Model aliases from `config/router.yaml`.

## What to Record

- End-to-end latency.
- Model alias used.
- Context settings.
- Hardware and runtime version details.

## Reproducibility Notes

- Keep one heavy model active at a time.
- Use the same prompt files across runs.
- Note any mode changes (offline or hybrid).
- Include environment metadata with each benchmark report.
