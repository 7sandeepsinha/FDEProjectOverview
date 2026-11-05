"""Bounded retry with exponential backoff and full jitter. Only transient failures are retried."""
 
import random
import time
from collections.abc import Callable
from typing import TypeVar
 
from meridian_workbench.llm_client import LlmRateLimited, LlmServerError, LlmTimeout
 
T = TypeVar("T")
RETRYABLE: tuple[type[Exception], ...] = (LlmTimeout, LlmRateLimited, LlmServerError)
 
 
def backoff_delay(attempt: int, base: float, cap: float, rng: random.Random) -> float:
    """A random wait from 0 up to the current ceiling. The ceiling doubles, up to the cap."""
    ceiling = min(cap, base * 2 ** (attempt - 1))
    return rng.uniform(0, ceiling)
 
 
def call_with_retry(
    operation: Callable[[], T],
    *,
    max_attempts: int,
    base: float,
    cap: float,
    rng: random.Random,
    sleep: Callable[[float], None] = time.sleep,
) -> T:
    if max_attempts < 1:
        raise ValueError("max_attempts must be at least 1")
    for attempt in range(1, max_attempts + 1):
        try:
            return operation()
        except RETRYABLE as error:
            if attempt == max_attempts:
                raise  # out of attempts: pass the original error up, with its traceback
            delay = backoff_delay(attempt, base, cap, rng)
            print(f"attempt {attempt} failed ({type(error).__name__}); waiting {delay:.2f}s")
            sleep(delay)
    raise AssertionError("unreachable: the loop always returns or raises")
