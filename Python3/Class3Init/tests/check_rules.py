"""Plain assertion checks for the attention rule. pytest arrives in Class 3."""
 
from datetime import date
 
from meridian_workbench.rules import days_overdue, needs_attention
 
BATCH_DATE = date(2025, 3, 10)
 
 
def run_checks():
    closed = {"order_status": "DELIVERED", "promised_date": "2025-03-06"}
    cancelled = {"order_status": "CANCELLED", "promised_date": "2025-03-05"}
    late = {"order_status": "SHIPPED", "promised_date": "2025-03-07"}
    early = {"order_status": "SHIPPED", "promised_date": "2025-03-12"}
 
    assert needs_attention(closed, BATCH_DATE) == (False, "CLOSED")
    assert needs_attention(cancelled, BATCH_DATE) == (False, "CLOSED")
    assert needs_attention(late, BATCH_DATE) == (True, "OVERDUE_NOT_CLOSED")
    assert needs_attention(early, BATCH_DATE) == (False, "ON_TIME")
    assert days_overdue("2025-03-07", BATCH_DATE) == 3
    print("All rule checks passed")
 
 
if __name__ == "__main__":
    run_checks()
