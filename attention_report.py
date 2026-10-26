"""Meridian Case Intake Workbench - V0: deterministic attention report."""
import csv
import json
from datetime import date
from pathlib import Path
 
DATA_DIR = Path("data")
OUTPUT_DIR = Path("outputs")
BATCH_DATE = date(2025, 3, 10)
CLOSED_STATUSES = {"DELIVERED", "CANCELLED"}

print(3 + "2")

def load_cases(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))
 
 
def load_notes(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)
 
 
def days_overdue(promised_date_text, as_of):
    """Whole days between the promised date and the batch date."""
    promised = date.fromisoformat(promised_date_text)
    return (as_of - promised).days
 
 
def needs_attention(case, as_of):
    """Return (flag, reason). Python decides this, never the model."""
    if case["order_status"] in CLOSED_STATUSES:
        return False, "CLOSED"
    if days_overdue(case["promised_date"], as_of) > 0:
        return True, "OVERDUE_NOT_CLOSED"
    return False, "ON_TIME"
 
 
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
 
 
def run_self_checks():
    closed = {"order_status": "DELIVERED", "promised_date": "2025-03-06"}
    late = {"order_status": "SHIPPED", "promised_date": "2025-03-07"}
    early = {"order_status": "SHIPPED", "promised_date": "2025-03-12"}
    assert needs_attention(closed, BATCH_DATE) == (False, "CLOSED")
    assert needs_attention(late, BATCH_DATE) == (True, "OVERDUE_NOT_CLOSED")
    assert needs_attention(early, BATCH_DATE) == (False, "ON_TIME")
    print("All rule checks passed")
 
def main():
    cases = load_cases(DATA_DIR / "cases.csv")
    notes = load_notes(DATA_DIR / "notes.json")
 
    notes_by_case = {}
    for note in notes:
        notes_by_case[note["case_id"]] = note
 
    results = []
    case_ids = []
    for case in cases:
        note = notes_by_case.get(case["case_id"])
        results.append(build_result(case, note, BATCH_DATE))
        case_ids.append(case["case_id"])
 
    assert len(results) == len(cases)
    assert len(set(case_ids)) == len(case_ids)
 
    OUTPUT_DIR.mkdir(exist_ok=True)
    with open(OUTPUT_DIR / "attention_report.json", "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)
 
    flagged_count = 0
    for r in results:
        if r["needs_attention"]:
            flagged_count += 1
            print(f"{r['case_id']}: {r['reason']} ({r['days_overdue']} days)")
    print(f"{flagged_count} of {len(results)} cases need attention")


run_self_checks()
main()