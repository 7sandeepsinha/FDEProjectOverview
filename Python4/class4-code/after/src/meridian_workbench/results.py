"""Build one evidence-backed result row per case. Facts and suggestions stay in separate keys."""
 
from dataclasses import asdict
from datetime import date
from typing import Any
 
from meridian_workbench.domain import CaseSuggestion, SourceEvidence, SupportCase
from meridian_workbench.rules import needs_attention
 
 
def build_result(case: SupportCase, note: SourceEvidence | None, as_of: date) -> dict[str, Any]:
    decision = needs_attention(case, as_of)
 
    if decision.needs_attention:
        evidence = (
            f"Status {case.order_status}, promised {case.promised_date.isoformat()}, "
            f"{decision.days_overdue} days overdue as of {as_of.isoformat()}"
        )
    else:
        evidence = (
            f"Not flagged ({decision.reason}). Status {case.order_status}, "
            f"promised {case.promised_date.isoformat()}"
        )
 
    return {
        "case_id": case.case_id,
        "order_id": case.order_id,
        "order_status": str(case.order_status),
        "promised_date": case.promised_date.isoformat(),
        "batch_date": as_of.isoformat(),
        "needs_attention": decision.needs_attention,
        "reason": str(decision.reason),
        "days_overdue": decision.days_overdue,
        "evidence": evidence,
        "source_note_id": note.note_id if note else None,
        "needs_interpretation": decision.needs_attention and note is not None,
        "suggestion": None,
    }
 
 
def suggestion_to_dict(suggestion: CaseSuggestion) -> dict[str, Any]:
    """Plain data for the JSON report. Enums become their text values."""
    data = asdict(suggestion)
    data["status"] = str(suggestion.status)
    data["issue_family"] = str(suggestion.issue_family) if suggestion.issue_family else None
    data["warnings"] = list(suggestion.warnings)
    return data
