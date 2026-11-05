"""Batch-level checks: required files, duplicate policy, the quality gate and the books."""
 
from pathlib import Path
 
from meridian_workbench.domain import Ledger, RejectCategory, SupportCase
from meridian_workbench.errors import (
    MissingSource,
    QualityGateFailed,
    ReconciliationError,
    RuleFailure,
)
 
REQUIRED_SOURCES = ("cases.csv", "notes.json", "shipments.csv", "inventory.csv")
DUPLICATE_POLICIES = ("first_wins", "reject_batch")
 
 
def require_sources(data_dir: Path) -> None:
    """Check every required file before reading any of them. Name all the missing ones at once."""
    missing = [name for name in REQUIRED_SOURCES if not (data_dir / name).is_file()]
    if missing:
        raise MissingSource(f"required source(s) missing from {data_dir}: {', '.join(missing)}")
 
 
def apply_duplicate_policy(
    rows: list[tuple[int, SupportCase]], ledger: Ledger, policy: str
) -> list[tuple[int, SupportCase]]:
    """A case_id must appear once. first_wins keeps the first row; reject_batch stops the batch."""
    if policy not in DUPLICATE_POLICIES:
        raise ValueError(f"unknown duplicate policy {policy!r}; use one of {DUPLICATE_POLICIES}")
    first_row: dict[str, int] = {}
    kept: list[tuple[int, SupportCase]] = []
    for row_number, case in rows:
        if case.case_id in first_row:
            if policy == "reject_batch":
                raise RuleFailure(
                    f"case_id {case.case_id} appears on rows {first_row[case.case_id]} "
                    f"and {row_number}; duplicate_policy is reject_batch"
                )
            ledger.reject(
                row_number,
                RejectCategory.DUPLICATE,
                f"{case.case_id},{case.order_id}",
                f"case_id {case.case_id} already appears on row {first_row[case.case_id]}; "
                "first_wins keeps that row",
            )
            continue
        first_row[case.case_id] = row_number
        kept.append((row_number, case))
    ledger.accepted = len(kept)
    return kept
 
 
def check_quality(ledger: Ledger, max_share: float) -> None:
    """Halt when too many rows were quarantined, or when the file is empty."""
    if ledger.input_rows == 0:
        raise QualityGateFailed(
            f"{ledger.source} has no data rows; an empty file is a problem, not a quiet success"
        )
    quarantined = len(ledger.rejected)
    share = quarantined / ledger.input_rows
    if share > max_share:
        raise QualityGateFailed(
            f"{ledger.source}: {quarantined} of {ledger.input_rows} rows ({share:.0%}) were "
            f"quarantined; the limit is {max_share:.0%}"
        )
 
 
def reconcile(ledger: Ledger) -> None:
    """Every input row is accepted or quarantined. Anything else is a bug, and we say so."""
    quarantined = len(ledger.rejected)
    if ledger.accepted + quarantined != ledger.input_rows:
        difference = ledger.input_rows - ledger.accepted - quarantined
        raise ReconciliationError(
            f"{ledger.source}: {ledger.input_rows} rows in, {ledger.accepted} accepted and "
            f"{quarantined} quarantined; difference of {difference} (not zero)"
        )
