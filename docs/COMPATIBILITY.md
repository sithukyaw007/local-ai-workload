# Compatibility Matrix

## Officially Tested Baseline

| Area | Baseline |
|---|---|
| OS | macOS (Apple Silicon) |
| Container runtime | Docker Desktop |
| Gateway | LiteLLM |
| Local runtimes | Ollama, llama.cpp |
| Client integration | Claude with local endpoint settings |

## Support Level

- Tier 1: macOS Apple Silicon + Docker Desktop + scripts in this repo.
- Tier 2: Adjacent environments where scripts still apply with minor changes.
- Tier 3: Community best-effort only.

## Notes

- Model-specific quality and latency vary by model size, quantization, and context.
- Hybrid mode requires explicit cloud credentials and policy acceptance.
