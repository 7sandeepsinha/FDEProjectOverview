"""Run the Meridian attention report from start to finish."""
 
import json
 
from meridian_workbench.config import load_settings
from meridian_workbench.loaders import load_cases, load_notes
from meridian_workbench.results import build_result
 
 
def main():
    settings = load_settings()
    cases = load_cases(settings["data_dir"] / "cases.csv")
    notes = load_notes(settings["data_dir"] / "notes.json")
 
    notes_by_case = {}
    for note in notes:
        notes_by_case[note["case_id"]] = note
 
    results = []
    case_ids = []
    for case in cases:
        note = notes_by_case.get(case["case_id"])
        results.append(build_result(case, note, settings["batch_date"]))
        case_ids.append(case["case_id"])
 
    assert len(results) == len(cases)
    assert len(set(case_ids)) == len(case_ids)
 
    settings["output_dir"].mkdir(exist_ok=True)
    with open(settings["output_dir"] / "attention_report.json", "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)
 
    flagged_count = 0
    for r in results:
        if r["needs_attention"]:
            flagged_count += 1
            print(f"{r['case_id']}: {r['reason']} ({r['days_overdue']} days)")
    print(f"{flagged_count} of {len(results)} cases need attention")
 
 
if __name__ == "__main__":
    main()
