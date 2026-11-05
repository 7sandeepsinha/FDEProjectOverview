"""Steps 3 and 4: both mismatches fixed.

Check it with: mypy rules_fixed.py
Run it with: python rules_fixed.py
"""

from dataclasses import dataclass
from datetime import date


@dataclass(frozen=True)
class SupportCase:
    case_id: str
    order_id: str
    order_status: str
    promised_date: date


CLOSED_STATUSES = {"DELIVERED", "CANCELLED"}


# Fix 2: the function was out of date, not the caller. It now takes a real date,
# so there is no text-to-date conversion left to do.
def days_overdue(promised_date: date, as_of: date) -> int:
    """Whole days between the promised date and the batch date."""
    return (as_of - promised_date).days


def needs_attention(case: SupportCase, as_of: date) -> tuple[bool, str]:
    """Return (flag, reason)."""
    if case.order_status in CLOSED_STATUSES:  # Fix 1: dots, not square brackets
        return False, "CLOSED"
    if days_overdue(case.promised_date, as_of) > 0:
        return True, "OVERDUE_NOT_CLOSED"
    return False, "ON_TIME"


if __name__ == "__main__":
    batch_date = date(2025, 3, 10)
    for case in [
        SupportCase("C-1001", "O-5001", "DELIVERED", date(2025, 3, 6)),
        SupportCase("C-1002", "O-5002", "SHIPPED", date(2025, 3, 7)),
        SupportCase("C-1003", "O-5003", "SHIPPED", date(2025, 3, 12)),
    ]:
        print(case.case_id, needs_attention(case, batch_date))