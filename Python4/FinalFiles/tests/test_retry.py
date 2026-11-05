"""Bounded retry: waits stay under the cap, and only transient errors are retried."""
 
import random
 
import pytest
 
from meridian_workbench.errors import MalformedRecord
from meridian_workbench.llm_client import LlmTimeout, MissingApiKeyError
from meridian_workbench.retry import backoff_delay, call_with_retry
 
 
def test_backoff_never_exceeds_the_cap() -> None:
    rng = random.Random(7)
    for attempt in range(1, 11):
        assert 0 <= backoff_delay(attempt, base=0.5, cap=8.0, rng=rng) <= 8.0
 
 
def test_transient_error_then_success_is_retried() -> None:
    calls = []
    waits: list[float] = []
 
    def flaky() -> str:
        calls.append(1)
        if len(calls) < 3:
            raise LlmTimeout("slow")
        return "ok"
 
    result = call_with_retry(
        flaky, max_attempts=3, base=0.5, cap=8.0, rng=random.Random(1), sleep=waits.append
    )
    assert result == "ok"
    assert len(calls) == 3
    assert len(waits) == 2
 
 
def test_missing_key_is_never_retried() -> None:
    calls = []
 
    def no_key() -> str:
        calls.append(1)
        raise MissingApiKeyError("MERIDIAN_LLM_API_KEY is not set")
 
    with pytest.raises(MissingApiKeyError):
        call_with_retry(
            no_key, max_attempts=3, base=0.5, cap=8.0, rng=random.Random(1), sleep=lambda s: None
        )
    assert len(calls) == 1
 
 
def test_data_errors_are_never_retried() -> None:
    calls = []
 
    def bad_data() -> str:
        calls.append(1)
        raise MalformedRecord("date is wrong")
 
    with pytest.raises(MalformedRecord):
        call_with_retry(
            bad_data, max_attempts=3, base=0.5, cap=8.0, rng=random.Random(1), sleep=lambda s: None
        )
    assert len(calls) == 1
