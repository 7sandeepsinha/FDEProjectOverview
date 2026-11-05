"""Domain construction: the types behave the way our vocabulary says they do."""
 
import dataclasses
from datetime import date
 
import pytest
 
from meridian_workbench.domain import (
    CaseSuggestion,
    Ledger,
    OrderStatus,
    RejectCategory,
    SupportCase,
)
 
 
def make_case() -> SupportCase:
    return SupportCase("C-1002", "O-5002", OrderStatus.SHIPPED, date(2025, 3, 7))
 
 
def test_support_case_is_frozen() -> None:
    case = make_case()
    with pytest.raises(dataclasses.FrozenInstanceError):
        case.order_status = OrderStatus.DELIVERED  # type: ignore[misc]
 
 
def test_unknown_status_is_rejected_by_the_enum() -> None:
    with pytest.raises(ValueError):
        OrderStatus("RETURNED")
 
 
def test_ledgers_do_not_share_their_lists() -> None:
    first, second = Ledger("a.csv"), Ledger("b.csv")
    first.reject(2, RejectCategory.MALFORMED, "raw", "reason")
    assert second.rejected == []
 
 
def test_suggestion_must_keep_case_id_and_source_note_id() -> None:
    with pytest.raises(ValueError):
        CaseSuggestion(case_id="", source_note_id="N-01")
    with pytest.raises(ValueError):
        CaseSuggestion(case_id="C-1002", source_note_id="")
 
 
def test_a_suggestion_is_not_a_fact() -> None:
    fact_fields = {f.name for f in dataclasses.fields(SupportCase)}
    assert "issue_family" not in fact_fields
    assert not issubclass(CaseSuggestion, SupportCase)
