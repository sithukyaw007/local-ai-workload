"""Auto-loaded by Python at startup. Patches litellm for local MLX backend."""
try:
    import litellm
    litellm.use_chat_completions_url_for_anthropic_messages = True
    litellm.drop_params = True
except ImportError:
    pass
