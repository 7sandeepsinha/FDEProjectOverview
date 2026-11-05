"""The attention rule, checked against known cases."""
 
from datetime import date
 
from meridian_workbench.domain import AttentionReason, OrderStatus, SupportCase
from meridian_workbench.rules import needs_attention
 
AS_OF = date(2025, 3, 10)
 
 
def case(status: OrderStatus, promised: date) -> SupportCase:
    return SupportCase("C-TEST", "O-TEST", status, promised)
 
 
def test_closed_case_is_never_flagged() -> None:
    decision = needs_attention(case(OrderStatus.DELIVERED, date(2025, 3, 1)), AS_OF)
    assert not decision.needs_attention
    assert decision.reason is AttentionReason.CLOSED
 
 
def test_overdue_open_case_is_flagged_with_days() -> None:
    decision = needs_attention(case(OrderStatus.SHIPPED, date(2025, 3, 7)), AS_OF)
    assert decision.needs_attention
    assert decision.days_overdue == 3
 
 
def test_promised_today_is_on_time() -> None:
    decision = needs_attention(case(OrderStatus.PROCESSING, AS_OF), AS_OF)
    assert not decision.needs_attention
    assert decision.reason is AttentionReason.ON_TIME
