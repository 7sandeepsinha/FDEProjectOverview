"""Run the attention report: intake gates, batch identity, rules, suggestions, rerun."""
 
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any
 
from meridian_workbench.ai_client import Caller, get_suggestion
from meridian_workbench.batch import (
    batch_id_for,
    log_attempt,
    new_attempt_id,
    write_json_atomic,
    write_quarantine,
)
from meridian_workbench.config import Settings, load_settings
from meridian_workbench.context import build_contexts
from meridian_workbench.domain import (
    InventoryInfo,
    Ledger,
    RejectedRecord,
    ShipmentInfo,
    SourceEvidence,
    SupportCase,
)
from meridian_workbench.errors import IntakeError, ReconciliationError
from meridian_workbench.llm_client import call_model
from meridian_workbench.loaders import load_cases, load_inventory, load_notes, load_shipments
from meridian_workbench.reconcile import (
    REQUIRED_SOURCES,
    apply_duplicate_policy,
    check_quality,
    reconcile,
    require_sources,
)
from meridian_workbench.results import build_result, suggestion_to_dict
 
 
@dataclass(frozen=True)
class Intake:
    cases: list[SupportCase]
    notes: list[SourceEvidence]
    shipments: dict[str, ShipmentInfo]
    inventory: dict[str, InventoryInfo]
    ledgers: list[Ledger]
    rejected: list[RejectedRecord]
 
 
def run_intake(data_dir: Path, settings: Settings, out_dir: Path) -> Intake:
    """Steps in order: files, rows, duplicates, quarantine, gate, books."""
    require_sources(data_dir)
    case_rows, cases_ledger = load_cases(data_dir / "cases.csv")
    notes, notes_ledger = load_notes(data_dir / "notes.json")
    shipments, shipments_ledger = load_shipments(data_dir / "shipments.csv")
    inventory, inventory_ledger = load_inventory(data_dir / "inventory.csv")
    case_rows = apply_duplicate_policy(case_rows, cases_ledger, settings.duplicate_policy)
 
    ledgers = [cases_ledger, notes_ledger, shipments_ledger, inventory_ledger]
    rejected = [record for ledger in ledgers for record in ledger.rejected]
    write_quarantine(
        rejected, out_dir / "quarantine.csv"
    )  # written before any gate can halt the run
    for ledger in ledgers:
        check_quality(ledger, settings.max_quarantine_share)
        reconcile(ledger)
    return Intake(
        cases=[case for _, case in case_rows],
        notes=notes,
        shipments=shipments,
        inventory=inventory,
        ledgers=ledgers,
        rejected=rejected,
    )
 
 
def process_cases(intake: Intake, settings: Settings, caller: Caller) -> list[dict[str, Any]]:
    contexts = build_contexts(intake.cases, intake.notes, intake.shipments, intake.inventory)
    results = []
    for context in contexts:
        note = context.notes[-1] if context.notes else None  # the latest note wins
        result = build_result(context.case, note, settings.batch_date)
        if result["needs_interpretation"] and note is not None:
            suggestion = get_suggestion(context.case.case_id, note, settings, caller=caller)
            result["suggestion"] = suggestion_to_dict(suggestion)
        results.append(result)
    return results
 
 
def build_summary(
    batch_id: str,
    attempt_id: str,
    settings: Settings,
    intake: Intake,
    results: list[dict[str, Any]],
) -> dict[str, Any]:
    flagged = []
    for r in results:
        if not r["needs_attention"]:
            continue
        s = r["suggestion"]
        flagged.append(
            {
                "case_id": r["case_id"],
                "reason": r["reason"],
                "days_overdue": r["days_overdue"],
                "suggestion": None
                if s is None
                else {
                    "status": s["status"],
                    "mode": s["meta"]["mode"],
                    "issue_family": s["issue_family"],
                    "review_required": s["review_required"],
                    "reason": s["reason"],
                },
            }
        )
    return {
        "batch_id": batch_id,
        "batch_date": settings.batch_date.isoformat(),
        "attempt_id": attempt_id,
        "duplicate_policy": settings.duplicate_policy,
        "files": [
            {
                "source": ledger.source,
                "input_rows": ledger.input_rows,
                "accepted": ledger.accepted,
                "quarantined": len(ledger.rejected),
            }
            for ledger in intake.ledgers
        ],
        "cases_total": len(results),
        "flagged": flagged,
        "rejected": [
            {
                "source": record.source,
                "row_number": record.row_number,
                "category": str(record.category),
                "reason": record.reason,
            }
            for record in intake.rejected
        ],
    }
 
 
def run_batch(data_dir: Path, settings: Settings, caller: Caller = call_model) -> dict[str, Any]:
    """Run one batch, or return the finished result of an earlier attempt at the same batch."""
    require_sources(data_dir)
    files = [data_dir / name for name in REQUIRED_SOURCES]
    rules = {
        "ai_mode": settings.ai_mode,
        "model": settings.model,
        "prompt_version": settings.prompt_version,
        "duplicate_policy": settings.duplicate_policy,
        "max_quarantine_share": settings.max_quarantine_share,
    }
    batch_id = batch_id_for(files, settings.batch_date, json.dumps(rules, sort_keys=True))
    out_dir = settings.output_dir / "batches" / batch_id
    attempt = new_attempt_id()
    summary_path = out_dir / "summary.json"
 
    if (
        summary_path.is_file()
    ):  # the marker is written last, so its presence means the batch finished
        log_attempt(out_dir, attempt, "reused finished batch; no work repeated")
        return json.loads(summary_path.read_text(encoding="utf-8"))
 
    out_dir.mkdir(parents=True, exist_ok=True)
    try:
        intake = run_intake(data_dir, settings, out_dir)
        results = process_cases(intake, settings, caller)
        if len(results) != intake.ledgers[0].accepted:
            raise ReconciliationError(
                f"{len(results)} results for {intake.ledgers[0].accepted} accepted cases"
            )
    except IntakeError as problem:
        log_attempt(out_dir, attempt, f"halted: {problem}")
        raise
 
    write_json_atomic(out_dir / "attention_report.json", results)
    summary = build_summary(batch_id, attempt, settings, intake, results)
    write_json_atomic(summary_path, summary)
    log_attempt(out_dir, attempt, "completed")
    return summary
 
 
def main() -> int:
    settings = load_settings()
    try:
        summary = run_batch(settings.data_dir, settings)
    except IntakeError as problem:
        print(f"HALTED: {problem}", file=sys.stderr)
        return 2
 
    for record in summary["rejected"]:
        print(
            f"REJECTED {record['source']} row {record['row_number']} "
            f"({record['category']}): {record['reason']}"
        )
    for ledger in summary["files"]:
        balanced = ledger["accepted"] + ledger["quarantined"] == ledger["input_rows"]
        print(
            f"{ledger['source']}: input {ledger['input_rows']}, accepted {ledger['accepted']}, "
            f"quarantined {ledger['quarantined']}, reconciled {'yes' if balanced else 'NO'}"
        )
    for item in summary["flagged"]:
        print(f"{item['case_id']}: {item['reason']} ({item['days_overdue']} days)")
        s = item["suggestion"]
        if s is None:
            continue
        if s["status"] == "OK":
            print(
                f"    suggestion ({s['mode']}): {s['issue_family']}, "
                f"review_required={s['review_required']}"
            )
        else:
            print(f"    suggestion ({s['mode']}): {s['status']} - {s['reason']}")
    flagged = len(summary["flagged"])
    print(f"{flagged} of {summary['cases_total']} cases need attention")
    print(f"batch {summary['batch_id']} (attempt {summary['attempt_id']})")
    return 0
