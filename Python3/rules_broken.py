from dataclasses import dataclass
from datetime import date


# The typed record from domain.py, inlined so this file stands alone.
@dataclass(frozen=True)
class SupportCase:
    case_id: str
    order_id: str
    order_status: str
    promised_date: date  # a real date now, not text


CLOSED_STATUSES = {"DELIVERED", "CANCELLED"}


def days_overdue(promised_date_text: str, as_of: date) -> int:
    """Whole days between the promised date and the batch date."""
    promised = date.fromisoformat(promised_date_text)
    return (as_of - promised).days


def needs_attention(case: SupportCase, as_of: date) -> tuple[bool, str]:
    """Return (flag, reason)."""
    if case["order_status"] in CLOSED_STATUSES:  # mismatch 1: a dataclass uses dots
        return False, "CLOSED"
    if days_overdue(case.promised_date, as_of) > 0:  # mismatch 2: date given, str expected
        return True, "OVERDUE_NOT_CLOSED"
    return False, "ON_TIME"

