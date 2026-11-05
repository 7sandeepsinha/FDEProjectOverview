"""Deterministic attention rules. Python decides this, never the model."""
 
from datetime import date
 
CLOSED_STATUSES = {"DELIVERED", "CANCELLED"}
 
 
def days_overdue(promised_date_text, as_of):
    """Whole days between the promised date and the batch date."""
    promised = date.fromisoformat(promised_date_text)
    return (as_of - promised).days
 
 
def needs_attention(case, as_of):
    """Return (flag, reason)."""
    if case["order_status"] in CLOSED_STATUSES:
        return False, "CLOSED"
    if days_overdue(case["promised_date"], as_of) > 0:
        return True, "OVERDUE_NOT_CLOSED"
    return False, "ON_TIME"
