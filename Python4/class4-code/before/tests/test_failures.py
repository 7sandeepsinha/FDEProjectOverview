"""Failure-path checks. Starter stubs: each one fails until you fill in its body in Section 8.
 
Read the docstring of each test. It says which promise the test protects and what to write.
Do not weaken an assertion to make a test pass. Make the program meet the promise.
"""
 
import pytest  # noqa: F401  (you will use pytest.raises in Section 8)
 
 
def test_malformed_date_is_quarantined(tmp_path):
    """Promise: a date we cannot read is never guessed. Write a one-row cases.csv whose promised_date is 07/03/2025.
    Load it with load_cases(). Assert: no accepted case, one rejected record, category MALFORMED, row_number 2,
    and the raw text still contains 07/03/2025."""
    assert False, "TODO (Section 8): write test_malformed_date_is_quarantined"
 
 
def test_impossible_date_is_quarantined(tmp_path):
    """Promise: 2025-02-30 looks like a date but is not one. Same pattern as the test above, with 2025-02-30.
    Assert that the reason says 'not a real calendar date'."""
    assert False, "TODO (Section 8): write test_impossible_date_is_quarantined"
 
 
def test_duplicate_case_id_first_wins(tmp_path):
    """Promise: a repeated case_id follows the declared policy, and the second row stays in the books.
    Write two rows with the same case_id. Apply apply_duplicate_policy with 'first_wins'.
    Assert: the first order_id is kept, ledger.accepted is 1, and the second row is a DUPLICATE on row 3."""
    assert False, "TODO (Section 8): write test_duplicate_case_id_first_wins"
 
 
def test_missing_required_source_stops_run(tmp_path):
    """Promise: a missing file stops the run before any work. Create a folder with only cases.csv.
    Assert that require_sources() raises MissingSource and the message names notes.json."""
    assert False, "TODO (Section 8): write test_missing_required_source_stops_run"
 
 
def test_reconciliation_balances():
    """Promise: every input row is accepted or quarantined. Load fixtures/cases_failures.csv,
    apply first_wins, then assert input_rows 8, accepted 4, quarantined 4. reconcile() must not raise.
    Then set accepted to 3 and assert reconcile() raises ReconciliationError."""
    assert False, "TODO (Section 8): write test_reconciliation_balances"
 
 
def test_timeout_is_unavailable_and_keeps_facts(settings_for):
    """Promise: a timeout never becomes an invented suggestion, and the facts stay.
    Use a fake caller that always raises LlmTimeout, and sleep=lambda s: None.
    Assert: status UNAVAILABLE, issue_family None, the caller was called settings.retry_max_attempts times,
    and build_result() still shows the order_status and promised_date unchanged."""
    assert False, "TODO (Section 8): write test_timeout_is_unavailable_and_keeps_facts"
 
 
def test_rate_limit_is_retried_then_unavailable(settings_for):
    """Promise: a rate limit gets bounded retries, then an honest UNAVAILABLE.
    Use a fake caller that always raises LlmRateLimited, and sleep=waits.append.
    Assert: UNAVAILABLE, the reason mentions 'rate limited', the caller ran 3 times,
    and there were exactly 2 waits, each no longer than retry_cap_seconds."""
    assert False, "TODO (Section 8): write test_rate_limit_is_retried_then_unavailable"
