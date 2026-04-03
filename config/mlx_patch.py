"""
LiteLLM custom callback to bypass Responses API routing for openai/ models.
Loaded via litellm_settings.callbacks in router.yaml.
"""
import litellm
from litellm.integrations.custom_logger import CustomLogger

class MLXPatch(CustomLogger):
    def __init__(self):
        super().__init__()
        litellm.use_chat_completions_url_for_anthropic_messages = True
        litellm.drop_params = True

_proxy_patch = MLXPatch()
