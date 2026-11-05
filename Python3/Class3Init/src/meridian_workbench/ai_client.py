"""The one place where the Workbench talks to a model.
 
Class 2 supports recorded responses only. The rules never import this file.
"""
 
import json
 
 
def get_suggestion(note_id, settings):
    """Return a suggestion for one note. The model only suggests, it never decides."""
    mode = settings["ai_mode"]
    if mode == "recorded":
        return _read_recorded(note_id, settings["fixtures_dir"])
    raise NotImplementedError(f"AI mode '{mode}' arrives in Class 3. Use 'recorded' for now.")
 
 
def _read_recorded(note_id, fixtures_dir):
    with open(fixtures_dir / "recorded_responses.json", encoding="utf-8") as f:
        responses = json.load(f)
    return responses.get(note_id)
