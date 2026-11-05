"""A thin model client. One call, bounded, with the facts we want to keep about it."""
 
from dataclasses import dataclass
 
from meridian_workbench.config import Settings
 
 
@dataclass(frozen=True)
class LlmReply:
    text: str
    model: str
    input_tokens: int
    output_tokens: int
    finish_reason: str
 
 
class LlmError(Exception):
    """Base class for every model-call problem."""
 
 
class MissingApiKeyError(LlmError):
    pass
 
 
class LlmCallFailed(LlmError):
    pass
 
 
def call_model(prompt: str, settings: Settings) -> LlmReply:
    if not settings.api_key:
        raise MissingApiKeyError("MERIDIAN_LLM_API_KEY is not set")
 
    import anthropic
 
    client = anthropic.Anthropic(
        api_key=settings.api_key, timeout=settings.timeout_seconds, max_retries=1
    )
    try:
        response = client.messages.create(
            model=settings.model,
            max_tokens=settings.max_tokens,
            messages=[{"role": "user", "content": prompt}],
        )
    except anthropic.APIError as error:
        # Name the kind of failure only. Never put the key or the request in the message.
        raise LlmCallFailed(type(error).__name__) from error
 
    text = "".join(block.text for block in response.content if block.type == "text")
    return LlmReply(
        text=text,
        model=response.model,
        input_tokens=response.usage.input_tokens,
        output_tokens=response.usage.output_tokens,
        finish_reason=str(response.stop_reason),
    )
