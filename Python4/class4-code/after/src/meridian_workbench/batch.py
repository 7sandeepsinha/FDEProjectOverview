"""Batch identity and output: a stable batch ID, a separate attempt ID, and files written safely."""
 
import csv
import hashlib
import json
import os
import uuid
from collections.abc import Sequence
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any
 
from meridian_workbench.domain import RejectedRecord
 
 
def batch_id_for(files: Sequence[Path], batch_date: date, rules_text: str) -> str:
    """The same files, date and rules always give the same ID, on any machine.
 
    rules_text holds every setting that can change an answer, so a live run never reuses
    recorded answers, and a different duplicate policy never reuses an old result.
    """
    digest = hashlib.sha256()
    digest.update(batch_date.isoformat().encode("utf-8"))
    digest.update(rules_text.encode("utf-8"))
    for path in sorted(
        files, key=lambda p: p.name
    ):  # sorted, so the order of listing cannot matter
        digest.update(path.name.encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return "B-" + digest.hexdigest()[:12]
 
 
def new_attempt_id() -> str:
    """Every run gets its own ID, so the attempt log can show each try separately."""
    return str(uuid.uuid4())
 
 
def write_json_atomic(path: Path, data: Any) -> None:
    """Write to a temporary name, then rename. A reader never sees a half-written file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + ".tmp")
    temp.write_text(json.dumps(data, indent=2, sort_keys=True), encoding="utf-8")
    os.replace(temp, path)
 
 
def write_quarantine(rejected: Sequence[RejectedRecord], path: Path) -> None:
    temp = path.with_name(path.name + ".tmp")
    with open(temp, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["source", "row_number", "category", "reason", "raw"])
        for record in sorted(rejected, key=lambda r: (r.source, r.row_number)):
            writer.writerow(
                [record.source, record.row_number, str(record.category), record.reason, record.raw]
            )
    os.replace(temp, path)
 
 
def log_attempt(out_dir: Path, attempt_id: str, outcome: str) -> None:
    stamp = datetime.now(UTC).isoformat(timespec="seconds")
    with open(out_dir / "attempts.log", "a", encoding="utf-8") as f:
        f.write(f"{stamp}  {attempt_id}  {outcome}\n")
