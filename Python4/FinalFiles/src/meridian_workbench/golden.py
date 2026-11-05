"""The starter golden set: load it, run it through the suggestion step, summarise hand scores."""
 
import csv
import json
import sys
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any
 
from meridian_workbench.ai_client import get_suggestion
from meridian_workbench.config import Settings, load_settings
from meridian_workbench.domain import IssueFamily, OrderStatus, SourceEvidence, SupportCase
from meridian_workbench.results import suggestion_to_dict
from meridian_workbench.rules import needs_attention
 
SCORE_COLUMNS = [
    "golden_id",
    "kind",
    "issue_family_correct",
    "evidence_grounded",
    "unsupported_claims",
    "abstention_correct",
    "comment",
]
YES_NO_COLUMNS = ["issue_family_correct", "evidence_grounded", "abstention_correct"]
 
 
@dataclass(frozen=True)
class GoldenItem:
    golden_id: str
    kind: str
    case: SupportCase
    note: SourceEvidence
    acceptable_issue_families: tuple[IssueFamily, ...]
    expected_evidence_span: str | None
    should_abstain: bool
 
 
def load_golden(path: Path) -> list[GoldenItem]:
    with open(path, encoding="utf-8") as f:
        raw = json.load(f)
    return [
        GoldenItem(
            golden_id=item["golden_id"],
            kind=item["kind"],
            case=SupportCase(
                item["case_id"],
                "O-" + item["case_id"],
                OrderStatus(item["order_status"]),
                date.fromisoformat(item["promised_date"]),
            ),
            note=SourceEvidence(item["note_id"], item["case_id"], item["note_text"]),
            acceptable_issue_families=tuple(
                IssueFamily(x) for x in item["acceptable_issue_families"]
            ),
            expected_evidence_span=item["expected_evidence_span"],
            should_abstain=item["should_abstain"],
        )
        for item in raw
    ]
 
 
def run_golden(items: list[GoldenItem], settings: Settings) -> list[dict[str, Any]]:
    rows = []
    for item in items:
        decision = needs_attention(item.case, settings.batch_date)
        row: dict[str, Any] = {
            "golden_id": item.golden_id,
            "kind": item.kind,
            "note_text": item.note.text,
            "rule_reason": str(decision.reason),
            "suggestion": None,
        }
        if decision.needs_attention:
            suggestion = get_suggestion(item.case.case_id, item.note, settings)
            row["suggestion"] = suggestion_to_dict(suggestion)
        rows.append(row)
    return rows
 
 
def write_blank_scoring_sheet(items: list[GoldenItem], path: Path) -> None:
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(SCORE_COLUMNS)
        for item in items:
            writer.writerow([item.golden_id, item.kind, "", "", "", "", ""])
 
 
def summarize_scores(path: Path) -> dict[str, str]:
    """Count the hand-entered marks. Y/N columns ignore blanks and NA. No model is involved."""
    yes: dict[str, int] = dict.fromkeys(YES_NO_COLUMNS, 0)
    total: dict[str, int] = dict.fromkeys(YES_NO_COLUMNS, 0)
    unsupported = 0
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            for column in YES_NO_COLUMNS:
                mark = row[column].strip().upper()
                if mark in ("Y", "N"):
                    total[column] += 1
                    yes[column] += mark == "Y"
            count = row["unsupported_claims"].strip()
            if count.isdigit():  # blanks and NA are skipped
                unsupported += int(count)
    summary = {column: f"{yes[column]} of {total[column]}" for column in YES_NO_COLUMNS}
    summary["unsupported_claims"] = str(unsupported)
    return summary
 
 
def main() -> None:
    settings = load_settings()
    items = load_golden(settings.golden_dir / "golden_set.json")
    command = sys.argv[1] if len(sys.argv) > 1 else "run"
 
    if command == "run":
        rows = run_golden(items, settings)
        settings.output_dir.mkdir(exist_ok=True)
        with open(settings.output_dir / "baseline_run.json", "w", encoding="utf-8") as f:
            json.dump(rows, f, indent=2)
        for row in rows:
            s = row["suggestion"]
            shown = (
                "(rule closes this case, no model call)"
                if s is None
                else (
                    f"{s['status']} {s['issue_family'] or ''} | evidence: {s['evidence_span']!r} | "
                    f"review_required={s['review_required']} | {s['meta']['mode']}"
                )
            )
            print(f"{row['golden_id']} {row['kind']:<12} {shown}")
    elif command == "blank-sheet":
        write_blank_scoring_sheet(items, settings.golden_dir / "scoring_baseline.csv")
        print("Wrote golden/scoring_baseline.csv")
    elif command == "score":
        for name, value in summarize_scores(settings.golden_dir / "scoring_baseline.csv").items():
            print(f"{name}: {value}")
    else:
        raise SystemExit("Use: python -m meridian_workbench.golden [run|blank-sheet|score]")
 
 
if __name__ == "__main__":
    main()
