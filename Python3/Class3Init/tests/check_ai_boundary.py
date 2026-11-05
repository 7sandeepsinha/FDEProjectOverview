"""Checks for the AI boundary: recorded mode works and the rules stay free of it."""
 
from pathlib import Path
 
from meridian_workbench.ai_client import get_suggestion
from meridian_workbench.config import load_settings
from meridian_workbench.loaders import load_notes
 
 
def run_checks():
    settings = load_settings()
    notes = {n["note_id"]: n for n in load_notes(settings["data_dir"] / "notes.json")}
 
    suggestion = get_suggestion("N-01", settings)
    assert suggestion["issue_family"] == "ADDRESS_CONFIRMATION"
    assert suggestion["evidence_span"] in notes["N-01"]["text"]
 
    abstained = get_suggestion("N-02", settings)
    assert abstained["issue_family"] is None
    assert abstained["review_required"] is True
 
    rules_file = Path(__file__).resolve().parents[1] / "src" / "meridian_workbench" / "rules.py"
    assert "ai_client" not in rules_file.read_text(encoding="utf-8")
    print("AI boundary checks passed")
 
 
if __name__ == "__main__":
    run_checks()
