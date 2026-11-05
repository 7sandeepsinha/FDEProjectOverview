"""A thin model client. One call, one timeout, and every failure translated into a name we own."""
 
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
    """No key is configured. Waiting will not add one, so this is never retried."""
 
 
class LlmTimeout(LlmError):
    """The service did not answer in time. Retryable."""
 
 
class LlmRateLimited(LlmError):
    """The service said 429 Too Many Requests. Retryable."""
 
 
class LlmServerError(LlmError):
    """The service answered with a 5xx error. Retryable."""
 
 
class LlmCallFailed(LlmError):
    """Any other failure from the SDK. Not retried."""
 
 
def call_model(prompt: str, settings: Settings) -> LlmReply:
    if not settings.api_key:
        raise MissingApiKeyError("MERIDIAN_LLM_API_KEY is not set")
 
    import anthropic
 
    client = anthropic.Anthropic(
        api_key=settings.api_key,
        timeout=settings.timeout_seconds,
        max_retries=0,  # our own retry in retry.py decides; the SDK must not add its own
    )
    try:
        response = client.messages.create(
            model=settings.model,
            max_tokens=settings.max_tokens,
            messages=[{"role": "user", "content": prompt}],
        )
    except anthropic.APITimeoutError as error:  # first: a timeout is also an APIError
        raise LlmTimeout("no reply within the timeout") from error
    except anthropic.RateLimitError as error:
        raise LlmRateLimited("rate limit reached (429)") from error
    except anthropic.InternalServerError as error:
        raise LlmServerError(f"server error ({error.status_code})") from error
    except anthropic.APIError as error:  # last: the catch-all
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
