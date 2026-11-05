"""Run the Meridian attention report from start to finish."""
 
import json
from typing import Any
 
from meridian_workbench.ai_client import get_suggestion
from meridian_workbench.config import Settings, load_settings
from meridian_workbench.context import build_contexts
from meridian_workbench.loaders import load_cases, load_inventory, load_notes, load_shipments
from meridian_workbench.results import build_result, suggestion_to_dict
 
 
def run(settings: Settings) -> list[dict[str, Any]]:
    batch = load_cases(settings.data_dir / "cases.csv")
    notes = load_notes(settings.data_dir / "notes.json")
    contexts = build_contexts(
        batch.cases,
        notes,
        load_shipments(settings.data_dir / "shipments.csv"),
        load_inventory(settings.data_dir / "inventory.csv"),
    )
 
    for rejected in batch.rejected:
        print(f"REJECTED row {rejected.row_number} of {rejected.source}: {rejected.reason}")
 
    results = []
    for context in contexts:
        note = context.notes[-1] if context.notes else None  # the latest note wins
        result = build_result(context.case, note, settings.batch_date)
        if result["needs_interpretation"] and note is not None:
            suggestion = get_suggestion(context.case.case_id, note, settings)
            result["suggestion"] = suggestion_to_dict(suggestion)
        results.append(result)
 
    assert len(results) == len(batch.cases)
    assert len({r["case_id"] for r in results}) == len(results)
    return results
 
 
def main() -> None:
    settings = load_settings()
    results = run(settings)
 
    settings.output_dir.mkdir(exist_ok=True)
    with open(settings.output_dir / "attention_report.json", "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)
 
    flagged_count = 0
    for r in results:
        if r["needs_attention"]:
            flagged_count += 1
            print(f"{r['case_id']}: {r['reason']} ({r['days_overdue']} days)")
            s = r["suggestion"]
            if s:
                label = s["issue_family"] or "ABSTAINED"
                mode = s["meta"]["mode"]
                print(f"    suggestion ({mode}): {label}, review_required={s['review_required']}")
    print(f"{flagged_count} of {len(results)} cases need attention")
 
 
if __name__ == "__main__":
    main()
