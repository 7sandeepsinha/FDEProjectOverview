"""The failure paths. Each test names one promise we made to the business."""
 
from collections.abc import Callable
from datetime import date
from pathlib import Path
 
import pytest
 
from meridian_workbench.ai_client import get_suggestion
from meridian_workbench.config import Settings, load_settings
from meridian_workbench.domain import (
    OrderStatus,
    RejectCategory,
    SourceEvidence,
    SuggestionStatus,
    SupportCase,
)
from meridian_workbench.errors import MissingSource, ReconciliationError
from meridian_workbench.llm_client import LlmRateLimited, LlmReply, LlmTimeout
from meridian_workbench.loaders import load_cases
from meridian_workbench.reconcile import apply_duplicate_policy, reconcile, require_sources
from meridian_workbench.results import build_result, suggestion_to_dict
 
NOTE = SourceEvidence("N-01", "C-1002", "Held at depot awaiting address confirmation")
 
 
def write_cases(path: Path, *rows: str) -> Path:
    path.write_text(
        "case_id,order_id,order_status,promised_date\n" + "\n".join(rows) + "\n", encoding="utf-8"
    )
    return path
 
 
def test_malformed_date_is_quarantined(tmp_path: Path) -> None:
    path = write_cases(tmp_path / "cases.csv", "C-1,O-1,SHIPPED,07/03/2025")
    rows, ledger = load_cases(path)
    assert rows == []
    assert ledger.accepted == 0
    assert len(ledger.rejected) == 1
    rejected = ledger.rejected[0]
    assert rejected.category is RejectCategory.MALFORMED
    assert rejected.row_number == 2
    assert "07/03/2025" in rejected.raw
    assert "YYYY-MM-DD" in rejected.reason
 
 
def test_impossible_date_is_quarantined(tmp_path: Path) -> None:
    path = write_cases(tmp_path / "cases.csv", "C-1,O-1,SHIPPED,2025-02-30")
    rows, ledger = load_cases(path)
    assert rows == []
    assert ledger.rejected[0].category is RejectCategory.MALFORMED
    assert "not a real calendar date" in ledger.rejected[0].reason
 
 
def test_duplicate_case_id_first_wins(tmp_path: Path) -> None:
    path = write_cases(
        tmp_path / "cases.csv",
        "C-1,O-1,PROCESSING,2025-03-09",
        "C-1,O-2,SHIPPED,2025-03-06",
    )
    rows, ledger = load_cases(path)
    kept = apply_duplicate_policy(rows, ledger, "first_wins")
    assert [case.order_id for _, case in kept] == ["O-1"]
    assert ledger.accepted == 1
    assert ledger.rejected[0].category is RejectCategory.DUPLICATE
    assert ledger.rejected[0].row_number == 3
 
 
def test_missing_required_source_stops_run(tmp_path: Path) -> None:
    (tmp_path / "cases.csv").write_text("case_id\n", encoding="utf-8")
    with pytest.raises(MissingSource, match="notes.json"):
        require_sources(tmp_path)
 
 
def test_reconciliation_balances() -> None:
    settings = load_settings()
    rows, ledger = load_cases(settings.fixtures_dir / "cases_failures.csv")
    apply_duplicate_policy(rows, ledger, "first_wins")
    assert ledger.input_rows == 8
    assert ledger.accepted == 4
    assert len(ledger.rejected) == 4
    reconcile(ledger)  # 4 accepted + 4 quarantined = 8 input rows: no error
    ledger.accepted = 3  # now one row is unaccounted for
    with pytest.raises(ReconciliationError, match="difference of 1"):
        reconcile(ledger)
 
 
def test_timeout_is_unavailable_and_keeps_facts(settings_for: Callable[..., Settings]) -> None:
    calls: list[str] = []
 
    def always_times_out(prompt: str, settings: Settings) -> LlmReply:
        calls.append(prompt)
        raise LlmTimeout("no reply within the timeout")
 
    settings = settings_for()
    case = SupportCase("C-1002", "O-5002", OrderStatus.SHIPPED, date(2025, 3, 7))
    suggestion = get_suggestion(
        "C-1002", NOTE, settings, caller=always_times_out, sleep=lambda s: None
    )
    assert suggestion.status is SuggestionStatus.UNAVAILABLE
    assert suggestion.issue_family is None
    assert suggestion.summary is None
    assert len(calls) == settings.retry_max_attempts
 
    row = build_result(case, NOTE, settings.batch_date)
    row["suggestion"] = suggestion_to_dict(suggestion)
    assert row["order_status"] == "SHIPPED"
    assert row["promised_date"] == "2025-03-07"
    assert row["suggestion"]["status"] == "UNAVAILABLE"
 
 
def test_rate_limit_is_retried_then_unavailable(settings_for: Callable[..., Settings]) -> None:
    calls: list[str] = []
    waits: list[float] = []
 
    def limited(prompt: str, settings: Settings) -> LlmReply:
        calls.append(prompt)
        raise LlmRateLimited("rate limit reached (429)")
 
    settings = settings_for()
    suggestion = get_suggestion("C-1002", NOTE, settings, caller=limited, sleep=waits.append)
    assert suggestion.status is SuggestionStatus.UNAVAILABLE
    assert "rate limited" in (suggestion.reason or "")
    assert len(calls) == settings.retry_max_attempts == 3
    assert len(waits) == 2  # no wait after the last attempt
    assert all(0 <= wait <= settings.retry_cap_seconds for wait in waits)
