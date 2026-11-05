"""Build one evidence-backed result per case."""
 
from meridian_workbench.rules import days_overdue, needs_attention
 
 
def build_result(case, note, as_of):
    flag, reason = needs_attention(case, as_of)
 
    days = 0
    if flag:
        days = days_overdue(case["promised_date"], as_of)
 
    note_id = None
    if note:
        note_id = note["note_id"]
 
    if flag:
        evidence = (
            f"Status {case['order_status']}, promised {case['promised_date']}, "
            f"{days} days overdue as of {as_of.isoformat()}"
        )
    else:
        evidence = (
            f"Not flagged ({reason}). Status {case['order_status']}, "
            f"promised {case['promised_date']}"
        )
 
    return {
        "case_id": case["case_id"],
        "order_id": case["order_id"],
        "order_status": case["order_status"],
        "promised_date": case["promised_date"],
        "batch_date": as_of.isoformat(),
        "needs_attention": flag,
        "reason": reason,
        "days_overdue": days,
        "evidence": evidence,
        "source_note_id": note_id,
        "needs_interpretation": flag and note is not None,
    }
