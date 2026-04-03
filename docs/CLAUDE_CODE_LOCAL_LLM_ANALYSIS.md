# Chain-of-Thought Analysis: Claude Code CLI with Local LLM via LiteLLM + Ollama MLX

> Full debugging journal of configuring Claude Code CLI to work with a local Qwen3.5-35B model on macOS Apple Silicon, routed through a LiteLLM gateway to Ollama 0.20+ with native MLX.

---

## Table of Contents

1. [Goal & Architecture](#1-goal--architecture)
2. [Attempt 1: Direct MLX Server + LiteLLM (`openai/` prefix)](#2-attempt-1-direct-mlx-server--litellm-openai-prefix)
3. [Attempt 2: Fix with `hosted_vllm/` prefix](#3-attempt-2-fix-with-hosted_vllm-prefix)
4. [Pivot: Ollama 0.20+ with native MLX](#4-pivot-ollama-020-with-native-mlx)
5. [Attempt 3: `hosted_vllm/` prefix with Ollama](#5-attempt-3-hosted_vllm-prefix-with-ollama)
6. [Attempt 4: `ollama_chat/` prefix (final fix)](#6-attempt-4-ollama_chat-prefix-final-fix)
7. [The Thinking Mode Problem](#7-the-thinking-mode-problem)
8. [Failed Attempts to Disable Thinking](#8-failed-attempts-to-disable-thinking)
9. [Final Fix: `think: false` in `litellm_params`](#9-final-fix-think-false-in-litellm_params)
10. [Final Configuration](#10-final-configuration)
11. [Key Lessons](#11-key-lessons)

---

## 1. Goal & Architecture

**Goal:** Make Claude Code CLI use a local LLM instead of Anthropic's cloud API, keeping all prompts and responses on-device.

**Target architecture:**

```
Claude Code CLI (Anthropic SDK format)
    │
    │  POST /v1/messages  (Anthropic Messages API)
    │  Headers: x-api-key, anthropic-version
    ▼
LiteLLM Gateway (Docker container, port 4000)
    │
    │  Translates Anthropic format → provider-native format
    │  Routes by model alias (local-coder-quality, etc.)
    ▼
Ollama 0.20+ (brew service, port 11434, MLX backend)
    │
    │  Runs qwen3.5:35b with native Apple Silicon MLX acceleration
    ▼
Response flows back through the same chain
```

**Why LiteLLM is needed:** Claude Code speaks the Anthropic Messages API (`/v1/messages`). Local models speak OpenAI-compatible (`/v1/chat/completions`) or provider-native APIs. LiteLLM translates between them.

**Why Ollama 0.20+:** Starting from v0.19, Ollama natively integrates Apple's MLX framework, giving ~57% faster prefill and ~2x faster decode on Apple Silicon compared to the old llama.cpp backend.

---

## 2. Attempt 1: Direct MLX Server + LiteLLM (`openai/` prefix)

### Setup

Initially tried routing LiteLLM to a standalone `mlx-lm server` (from the `local-mac-ai` project) running Qwen3.5-35B-A3B-4bit on port 8000.

```yaml
# router.yaml — first attempt
model_list:
  - model_name: local-coder-quality
    litellm_params:
      model: openai/mlx-community/Qwen3.5-35B-A3B-4bit
      api_base: http://host.docker.internal:8000/v1
      api_key: dummy
```

### What happened

**OpenAI-style `/v1/chat/completions` worked fine:**

```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer local-ai-workload" \
  -d '{"model": "local-coder-quality", "messages": [{"role": "user", "content": "hello"}], "max_tokens": 50}'
# ✅ 200 OK — response returned
```

**But Anthropic-style `/v1/messages` failed with 404:**

```bash
curl http://localhost:4000/v1/messages \
  -H "x-api-key: local-ai-workload" -H "anthropic-version: 2023-06-01" \
  -d '{"model": "local-coder-quality", "messages": [{"role": "user", "content": "hello"}], "max_tokens": 200}'
# ❌ 404: "Received Model Group=local-coder-quality, Available Model Group Fallbacks=None"
```

### Root cause analysis

Traced through LiteLLM 1.82.0 source code inside the Docker container:

```python
# /app/litellm/llms/anthropic/experimental_pass_through/messages/handler.py

# Line 40 — the smoking gun:
_RESPONSES_API_PROVIDERS = frozenset({"openai"})

def _should_route_to_responses_api(custom_llm_provider):
    if litellm.use_chat_completions_url_for_anthropic_messages:
        return False
    return custom_llm_provider in _RESPONSES_API_PROVIDERS
```

**The chain of failure:**

1. Claude Code sends `POST /v1/messages` (Anthropic format)
2. LiteLLM's Anthropic handler receives it
3. Handler checks the model's provider prefix — `openai/` matches `_RESPONSES_API_PROVIDERS`
4. Routes to the **OpenAI Responses API** path (`litellm.aresponses()`)
5. `aresponses()` tries to call `http://host.docker.internal:8000/v1/responses`
6. MLX server doesn't have a `/v1/responses` endpoint → **404**

**Why `/v1/chat/completions` worked:** That endpoint uses a completely different code path (`litellm.acompletion()`) that doesn't go through the Anthropic handler.

### Attempted fix: `use_chat_completions_url_for_anthropic_messages`

The source code showed a bypass flag:

```yaml
litellm_settings:
  use_chat_completions_url_for_anthropic_messages: true
```

**Result: Failed.** Running `docker exec ... python -c "import litellm; print(litellm.use_chat_completions_url_for_anthropic_messages)"` returned `False` — the setting wasn't being loaded. This feature likely didn't exist in LiteLLM 1.82.0 despite being referenced in the code.

---

## 3. Attempt 2: Fix with `hosted_vllm/` prefix

### Reasoning

Since the Responses API routing is triggered by `custom_llm_provider in {"openai"}`, changing the prefix to anything other than `openai/` would bypass it.

`hosted_vllm/` is designed for OpenAI-compatible servers and would NOT match:

```python
>>> "hosted_vllm" in {"openai"}
False  # Won't route to Responses API ✅
```

### Config change

```yaml
model_list:
  - model_name: local-coder-quality
    litellm_params:
      model: hosted_vllm/mlx-community/Qwen3.5-35B-A3B-4bit
      api_base: http://host.docker.internal:8000/v1
      api_key: dummy
```

### Result

`/v1/messages` now returned **200 OK** — the Anthropic endpoint worked.

### New problem: Claude Code sent unsupported parameters

```
litellm.UnsupportedParamsError: openai does not support parameters:
  ['reasoning_effort', 'context_management']
```

Claude Code sends Anthropic-specific params that local backends don't understand.

**Fix:** Added `drop_params: true` to silently drop unsupported parameters:

```yaml
litellm_settings:
  drop_params: true
```

### Next problem: Claude Code sent `?beta=true`

Claude Code actually calls `/v1/messages?beta=true`, which hit a different code path in LiteLLM that still routed through the Responses API despite the `hosted_vllm/` prefix:

```
[log_0a62b2] post http://localhost:4000/v1/messages?beta=true failed with status 404
```

This was a dead end — the `?beta=true` variant bypassed the fix.

---

## 4. Pivot: Ollama 0.20+ with native MLX

### Why pivot

1. The standalone MLX server + LiteLLM gateway had persistent format/routing issues
2. Ollama 0.19+ ships with native MLX support on Apple Silicon
3. Ollama provides a simpler, battle-tested API that LiteLLM understands well
4. Better model management (`ollama pull` vs manual HuggingFace downloads)
5. Intelligent KV cache checkpoints across sessions

### Upgrade

```bash
brew upgrade ollama
# 0.17.7 -> 0.20.0 (installed mlx 0.31.1, mlx-c 0.6.0 as dependencies)

brew services restart ollama
ollama pull qwen3.5:35b  # ~23 GB download, MLX auto-enabled on Apple Silicon
```

---

## 5. Attempt 3: `hosted_vllm/` prefix with Ollama

### Config

```yaml
model_list:
  - model_name: local-coder-quality
    litellm_params:
      model: hosted_vllm/qwen3.5:35b
      api_base: http://host.docker.internal:11434/v1
      api_key: ollama
```

### What happened

**First message worked:**

```
❯ hi there
⏺ Hi! How can I help you today?
✻ Sautéed for 1m 36s   # ← extremely slow, but that's a separate issue
```

**Second message failed:**

```
❯ how are you doing?
⎿ API Error: 400 {"error":{"message":"Hosted_vllmException -
   {\"error\":{\"message\":\"invalid message format\"...}}"}}
```

### Root cause

On the second message, Claude Code sends the **conversation history** including the assistant's previous response. That response contained Anthropic-format content blocks:

```json
{
  "role": "assistant",
  "content": [
    {"type": "thinking", "thinking": "..."},
    {"type": "text", "text": "Hi! How can I help you today?"}
  ]
}
```

The `hosted_vllm/` provider passed these content arrays directly to Ollama's `/v1/chat/completions` endpoint. Ollama expected plain string content and rejected the array format:

```json
{"error": {"message": "invalid message format"}}
```

---

## 6. Attempt 4: `ollama_chat/` prefix (final fix)

### Reasoning

LiteLLM has a dedicated `ollama_chat` provider that:

1. Uses Ollama's **native** `/api/chat` endpoint (not OpenAI-compatible)
2. Properly formats messages for Ollama, including stripping/converting content block arrays
3. Does NOT match `_RESPONSES_API_PROVIDERS` (avoids the Responses API bug)
4. Maps `reasoning_effort` → `think` parameter natively

```python
>>> "ollama_chat" in {"openai"}
False  # Won't route to Responses API ✅
```

### Config change

```yaml
model_list:
  - model_name: local-coder-quality
    litellm_params:
      model: ollama_chat/qwen3.5:35b
      api_base: http://host.docker.internal:11434  # Note: no /v1 suffix
```

### Result

- ✅ `/v1/messages` works (Anthropic format)
- ✅ Multi-turn conversation works (proper message formatting)
- ✅ Claude Code smoke test passes

**But responses were still extremely slow (1m 36s for "hello").** This was the thinking mode problem.

---

## 7. The Thinking Mode Problem

### Symptoms

Claude Code took 1 minute 36 seconds to respond to "hi there".

### Diagnosis

Tested directly:

```bash
curl http://localhost:4000/v1/messages \
  -d '{"model": "local-coder-quality",
       "messages": [{"role": "user", "content": "hello"}],
       "system": "You are a helpful coding assistant. Be concise.",
       "max_tokens": 1000}'
```

**Response:** 396 output tokens, 14 seconds

- **~380 tokens** were invisible "thinking" reasoning
- **~12 tokens** were the actual visible answer ("Hello! How can I help you with your coding today?")

### What's happening

Qwen3.5 has a built-in "thinking mode" (enabled by default) that generates internal chain-of-thought reasoning inside `<think>...</think>` tags before producing the visible answer.

For a simple "hello", the model spent 380 tokens thinking:

```
Thinking Process:
1. Analyze the Input: The user inputs "hello" which is a simple greeting.
2. Determine the intent: The user is testing the interaction...
3. Review guidelines: The prompt provided is "You are a helpful coding assistant. Be concise."
4. Formulate response: "Hello! How can I assist you with your coding today?"
5. Refining for conciseness...
6. Final decision: Keep it friendly but focused...
7. Wait, looking at the prompt system instructions...
8. Okay, the user just said "hello". I shouldn't overthink it.
```

With Claude Code's much larger system prompts (tools, instructions, file context), the thinking overhead is even worse — hence 1m 36s.

### Token budget comparison

| Mode | Tokens for "hello" | Time (warm) | Useful tokens |
|------|-------------------|-------------|---------------|
| Thinking ON | ~396 | ~14s | ~12 (3%) |
| Thinking OFF | ~10 | ~0.8s | ~10 (100%) |

---

## 8. Failed Attempts to Disable Thinking

### Attempt 8a: `/no_think` in Ollama SYSTEM directive

```dockerfile
FROM qwen3.5:35b
SYSTEM "/no_think"
```

**Result: Failed.** The model acknowledged `/no_think` in its thinking output ("This is a directive to skip the thinking process") but still generated thinking tokens anyway. The `/no_think` directive only works when placed directly in user message content, not in system prompts via Ollama's Modelfile.

### Attempt 8b: Custom template with `/no_think` injection

```dockerfile
FROM qwen3.5:35b
TEMPLATE """{{- if .System }}<|im_start|>system
/no_think {{ .System }}<|im_end|>
{{ end }}<|im_start|>user
{{ .Prompt }}<|im_end|>
<|im_start|>assistant
"""
```

**Result: Failed.** Same behavior — model still generated thinking tokens. The TEMPLATE approach conflicts with Ollama's built-in `RENDERER qwen3.5` / `PARSER qwen3.5` which handles the actual chat formatting.

### Attempt 8c: `think: false` as Modelfile PARAMETER

```dockerfile
FROM qwen3.5:35b
PARAMETER think false
```

**Result: Error.** Ollama rejected it: `Error: unknown parameter 'think'`. The `think` parameter is a request-time API parameter, not a Modelfile configuration option.

### Attempt 8d: `think` via OpenAI-compatible endpoint

```bash
curl http://localhost:11434/v1/chat/completions \
  -d '{"model": "qwen3.5:35b", "think": false, ...}'
```

**Result: Failed.** Ollama's OpenAI-compatible endpoint ignores the `think` parameter. Only the native `/api/chat` endpoint respects it.

### What DID work: `think: false` via Ollama native API

```bash
curl http://localhost:11434/api/chat \
  -d '{"model": "qwen3.5:35b", "think": false,
       "messages": [{"role": "user", "content": "Say hello"}], "stream": false}'
```

**Result: 3 tokens, 0.9 seconds.** The `think` parameter works, but only on the native `/api/chat` endpoint.

---

## 9. Final Fix: `think: false` in `litellm_params`

### Discovery

Deep in LiteLLM's ollama chat transformation code:

```python
# /app/litellm/llms/ollama/chat/transformation.py

# Line 255: 'think' is extracted from optional_params
think = optional_params.pop("think", None)

# Line 319-320: 'think' is injected into the request body
if think is not None:
    data["think"] = think
```

LiteLLM's `ollama_chat` provider builds the Ollama native API request body. If `think` is present in the params, it gets forwarded to Ollama.

### How `litellm_params` works

LiteLLM's router config allows arbitrary keys in `litellm_params`. When a request is made, these params are merged into the completion call. Since `ollama_chat` explicitly handles `think`, setting it in the config propagates it to every request.

### The fix

```yaml
model_list:
  - model_name: local-coder-quality
    litellm_params:
      model: ollama_chat/qwen3.5:35b
      api_base: http://host.docker.internal:11434
      think: false  # ← This is the key line
```

### Result

```bash
# Before (thinking enabled)
curl /v1/messages -d '{"model":"local-coder-quality","messages":[...],"max_tokens":200}'
# → 200 tokens, 10+ seconds, mostly invisible thinking

# After (thinking disabled)
curl /v1/messages -d '{"model":"local-coder-quality","messages":[...],"max_tokens":200}'
# → 10 tokens, 0.8 seconds, 100% useful content
```

---

## 10. Final Configuration

### Architecture (working)

```
Claude Code CLI
    │  POST /v1/messages (Anthropic format)
    │  x-api-key: from macOS Keychain via apiKeyHelper
    ▼
LiteLLM 1.82.0 (Docker, port 4000)
    │  Translates Anthropic → Ollama native format
    │  Provider: ollama_chat (uses /api/chat, not /v1/chat/completions)
    │  Injects think: false on every request
    │  Drops unsupported params (context_management, etc.)
    ▼
Ollama 0.20.0 (brew service, port 11434, MLX backend)
    │  Model: qwen3.5:35b (~23 GB, native MLX on Apple Silicon)
    │  Thinking: disabled via think: false
    ▼
Response (Anthropic format) back to Claude Code
```

### `config/router.yaml`

```yaml
model_list:
  - model_name: local-coder-fast
    litellm_params:
      model: ollama_chat/qwen3.5:35b
      api_base: http://host.docker.internal:11434
      think: false

  - model_name: local-coder-quality
    litellm_params:
      model: ollama_chat/qwen3.5:35b
      api_base: http://host.docker.internal:11434
      think: false

  - model_name: local-general
    litellm_params:
      model: ollama_chat/qwen3.5:35b
      api_base: http://host.docker.internal:11434
      think: false

  - model_name: cloud-fallback
    litellm_params:
      model: openai/gpt-4.1-mini
      api_key: os.environ/CLOUD_API_KEY
      api_base: os.environ/CLOUD_API_BASE

router_settings:
  routing_strategy: usage-based-routing
  allowed_fails: 2
  cooldown_time: 15
  enable_pre_call_checks: true

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  health_check_interval: 60
  infer_model_from_keys: false

litellm_settings:
  default_internal_model: local-coder-quality
  drop_params: true
```

### `.claude/settings.local.json`

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "apiKeyHelper": "/Users/sithukyaw/work/local-ai-workload/scripts/claude-api-key-helper.sh",
  "model": "local-coder-quality",
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:4000",
    "ANTHROPIC_MODEL": "local-coder-quality"
  }
}
```

---

## 11. Key Lessons

### 1. LiteLLM provider prefix matters enormously

| Prefix | `/v1/messages` | Multi-turn | Think control | API format |
|--------|---------------|------------|---------------|------------|
| `openai/` | ❌ Routes to Responses API | ✅ | ❌ | OpenAI `/v1/chat/completions` |
| `hosted_vllm/` | ✅ | ❌ Ollama rejects content arrays | ❌ | OpenAI `/v1/chat/completions` |
| `ollama_chat/` | ✅ | ✅ | ✅ | Ollama native `/api/chat` |

**Always use `ollama_chat/` for Ollama backends through LiteLLM.**

### 2. The Responses API routing bug in LiteLLM 1.82+

LiteLLM's `/v1/messages` handler has a hard-coded provider check:

```python
_RESPONSES_API_PROVIDERS = frozenset({"openai"})
```

Any model with `openai/` prefix will be routed through the OpenAI Responses API (`/v1/responses`), which most local backends don't support. This is not documented and causes opaque 404 errors.

### 3. Qwen3/3.5 thinking mode is a hidden performance killer

- Default: **enabled** — generates 300-700+ reasoning tokens before every answer
- For agentic workflows (frequent short interactions), this is 10-100x overhead
- The only reliable disable mechanism is `think: false` in the Ollama API
- `/no_think` in system prompts does NOT work reliably
- Ollama Modelfile `PARAMETER think false` is NOT supported

### 4. `drop_params: true` is essential for local model setups

Claude Code sends Anthropic-specific parameters (`reasoning_effort`, `context_management`) that local backends don't understand. Without `drop_params: true`, LiteLLM returns 400 errors.

**Important nuance:** `drop_params` only drops parameters that the provider declares as "unsupported". The `ollama_chat` provider declares `reasoning_effort` as supported (it maps to `think`), so it won't be dropped — it gets properly translated.

### 5. Cold start vs warm performance

| Metric | Cold start | Warm cache |
|--------|-----------|------------|
| Response time | ~14 seconds | **< 1 second** |
| Cause | Model loaded into GPU memory | Model already resident |

The first request after idle triggers a model load. Subsequent requests are fast. Ollama 0.20+ has improved cache management that keeps models resident longer.

### 6. The `?beta=true` query parameter

Claude Code appends `?beta=true` to `/v1/messages` requests. Some LiteLLM code paths handle this differently from plain `/v1/messages`, which can cause routing inconsistencies. The `ollama_chat/` provider handles both correctly.
