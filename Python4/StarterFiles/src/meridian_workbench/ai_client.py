"""The one place where the Workbench turns a note into a model suggestion.
 
The rules never import this file. The model only suggests, it never decides.
"""
 
import json
from collections.abc import Callable
from typing import Any
 
from meridian_workbench.config import Settings
from meridian_workbench.domain import (
    CallMetadata,
    CaseSuggestion,
    IssueFamily,
    SourceEvidence,
)
from meridian_workbench.llm_client import LlmError, LlmReply, call_model
 
Caller = Callable[[str, Settings], LlmReply]
 
 
def build_prompt(note: SourceEvidence) -> str:
    families = ", ".join(family.value for family in IssueFamily)
    return (
        "You help a support team triage delivery problems. "
        "Read the note and return ONE JSON object and nothing else.\n"
        "Keys:\n"
        f"  issue_family: one of {families}, or null\n"
        "  summary: one sentence that uses only facts stated in the note, or null\n"
        "  evidence_span: an exact quote copied from the note that supports issue_family, or null\n"
        "  review_required: true if you are unsure or more than one family fits\n"
        "If the note does not say what the problem is, set issue_family, summary and "
        "evidence_span to null and review_required to true. Do not guess.\n"
        f"Note: {note.text}"
    )
 
 
def suggestion_from_data(
    data: dict[str, Any], case_id: str, note: SourceEvidence, meta: CallMetadata
) -> CaseSuggestion:
    warnings: list[str] = []
 
    family: IssueFamily | None = None
    raw_family = data.get("issue_family")
    if raw_family is not None:
        try:
            family = IssueFamily(raw_family)
        except ValueError:
            warnings.append(f"unknown issue_family '{raw_family}'")
 
    span = data.get("evidence_span")
    if span is not None and span not in note.text:
        warnings.append("evidence_span does not appear in the note")
 
    abstained = bool(data.get("abstained")) or family is None
    review = bool(data.get("review_required", True)) or abstained or bool(warnings)
    return CaseSuggestion(
        case_id=case_id,
        source_note_id=note.note_id,
        issue_family=family,
        summary=data.get("summary"),
        evidence_span=span,
        review_required=review,
        abstained=abstained,
        abstain_reason=data.get("abstain_reason") or ("no issue family" if abstained else None),
        warnings=tuple(warnings),
        meta=meta,
    )
 
 
def parse_reply(
    text: str, case_id: str, note: SourceEvidence, meta: CallMetadata
) -> CaseSuggestion:
    start, end = text.find("{"), text.rfind("}")
    try:
        data = json.loads(text[start : end + 1])
        if not isinstance(data, dict):
            raise ValueError("reply is not a JSON object")
    except ValueError:
        return CaseSuggestion(
            case_id=case_id,
            source_note_id=note.note_id,
            abstained=True,
            abstain_reason="the reply was not valid JSON",
            meta=meta,
        )
    return suggestion_from_data(data, case_id, note, meta)
 
 
def read_recorded(
    case_id: str, note: SourceEvidence, settings: Settings, mode: str, fallback_reason: str | None
) -> CaseSuggestion:
    with open(settings.fixtures_dir / "recorded_responses.json", encoding="utf-8") as f:
        responses = json.load(f)
    meta = CallMetadata(
        mode, "recorded", settings.prompt_version, 0, 0, "recorded", fallback_reason
    )
    data = responses.get(note.note_id)
    if data is None:
        return CaseSuggestion(
            case_id=case_id,
            source_note_id=note.note_id,
            abstained=True,
            abstain_reason="no recorded response for this note",
            meta=meta,
        )
    return suggestion_from_data(data, case_id, note, meta)
 
 
def get_suggestion(
    case_id: str, note: SourceEvidence, settings: Settings, caller: Caller = call_model
) -> CaseSuggestion:
    if settings.ai_mode == "recorded":
        return read_recorded(case_id, note, settings, "recorded", None)
 
    try:
        reply = caller(build_prompt(note), settings)
    except LlmError as error:
        return read_recorded(case_id, note, settings, "recorded_fallback", str(error))
 
    meta = CallMetadata(
        "live",
        reply.model,
        settings.prompt_version,
        reply.input_tokens,
        reply.output_tokens,
        reply.finish_reason,
    )
    return parse_reply(reply.text, case_id, note, meta)
