"""Deterministic attention rules. Python decides this, never the model."""
 
from datetime import date
 
from meridian_workbench.domain import (
    AttentionDecision,
    AttentionReason,
    OrderStatus,
    SupportCase,
)
 
CLOSED_STATUSES = frozenset({OrderStatus.DELIVERED, OrderStatus.CANCELLED})
 
 
def days_overdue(promised_date: date, as_of: date) -> int:
    """Whole days between the promised date and the batch date."""
    return (as_of - promised_date).days
 
 
def needs_attention(case: SupportCase, as_of: date) -> AttentionDecision:
    if case.order_status in CLOSED_STATUSES:
        return AttentionDecision(case.case_id, False, AttentionReason.CLOSED, 0)
    days = days_overdue(case.promised_date, as_of)
    if days > 0:
        return AttentionDecision(case.case_id, True, AttentionReason.OVERDUE_NOT_CLOSED, days)
    return AttentionDecision(case.case_id, False, AttentionReason.ON_TIME, 0)
