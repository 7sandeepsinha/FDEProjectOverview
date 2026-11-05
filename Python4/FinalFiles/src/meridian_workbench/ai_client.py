"""The one place where the Workbench turns a note into a model suggestion.
 
The rules never import this file. The model only suggests, it never decides.
Every outcome ends in one SuggestionStatus. A missing answer is never replaced by an invented one.
"""
 
import json
import random
import time
from collections.abc import Callable
from pathlib import Path
from typing import Any
 
from meridian_workbench.batch import write_json_atomic
from meridian_workbench.config import Settings
from meridian_workbench.domain import (
    CallMetadata,
    CaseSuggestion,
    IssueFamily,
    SourceEvidence,
    SuggestionStatus,
)
from meridian_workbench.errors import RuleFailure
from meridian_workbench.llm_client import (
    LlmError,
    LlmRateLimited,
    LlmReply,
    LlmTimeout,
    call_model,
)
from meridian_workbench.retry import call_with_retry
 
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
 
 
def _status(
    case_id: str,
    note: SourceEvidence,
    meta: CallMetadata,
    status: SuggestionStatus,
    reason: str,
) -> CaseSuggestion:
    return CaseSuggestion(
        case_id=case_id,
        source_note_id=note.note_id,
        status=status,
        review_required=True,
        reason=reason,
        meta=meta,
    )
 
 
def interpret_reply(
    text: str, case_id: str, note: SourceEvidence, meta: CallMetadata
) -> CaseSuggestion:
    """Turn the text of a reply into one status. The shape is checked strictly."""
    start, end = text.find("{"), text.rfind("}")
    try:
        data: Any = json.loads(text[start : end + 1])
    except json.JSONDecodeError:
        return _status(
            case_id, note, meta, SuggestionStatus.INVALID_REPLY, "the reply was not valid JSON"
        )
 
    if not isinstance(data, dict) or "issue_family" not in data:
        return _status(
            case_id,
            note,
            meta,
            SuggestionStatus.INVALID_REPLY,
            "the reply has no issue_family field",
        )
 
    raw_family = data["issue_family"]
    if raw_family is None:
        reason = str(data.get("abstain_reason") or "the note does not say what the problem is")
        return _status(case_id, note, meta, SuggestionStatus.ABSTAINED, reason)
 
    try:
        family = IssueFamily(raw_family)
    except ValueError:
        return _status(
            case_id,
            note,
            meta,
            SuggestionStatus.INVALID_REPLY,
            f"unknown issue_family {raw_family!r}",
        )
 
    summary = data.get("summary")
    span = data.get("evidence_span")
    if not isinstance(summary, str):
        return _status(case_id, note, meta, SuggestionStatus.INVALID_REPLY, "summary must be text")
    if span is not None and not isinstance(span, str):
        return _status(
            case_id,
            note,
            meta,
            SuggestionStatus.INVALID_REPLY,
            "evidence_span must be text or null",
        )
 
    warnings: list[str] = []
    if span is None:
        warnings.append("no evidence_span was quoted")
    elif span not in note.text:
        warnings.append("evidence_span does not appear in the note")
    review = bool(data.get("review_required", True)) or bool(warnings)
    return CaseSuggestion(
        case_id=case_id,
        source_note_id=note.note_id,
        status=SuggestionStatus.OK,
        issue_family=family,
        summary=summary,
        evidence_span=span,
        review_required=review,
        warnings=tuple(warnings),
        meta=meta,
    )
 
 
def read_recorded(case_id: str, note: SourceEvidence, settings: Settings) -> CaseSuggestion:
    with open(settings.fixtures_dir / "recorded_responses.json", encoding="utf-8") as f:
        responses = json.load(f)
    meta = CallMetadata("recorded", "recorded", settings.prompt_version, 0, 0, "recorded")
    data = responses.get(note.note_id)
    if data is None:
        return _status(
            case_id,
            note,
            meta,
            SuggestionStatus.ABSTAINED,
            "no recorded response exists for this note",
        )
    # A recorded answer goes through the same parser as a live one, so the two cannot drift apart.
    return interpret_reply(json.dumps(data), case_id, note, meta)
 
 
def load_cache(path: Path) -> dict[str, str]:
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise RuleFailure(f"{path.name} is not valid JSON; delete it and run again") from error
    return data
 
 
def _unavailable(
    case_id: str, note: SourceEvidence, settings: Settings, reason: str
) -> CaseSuggestion:
    meta = CallMetadata("live", settings.model, settings.prompt_version, 0, 0, "unavailable")
    return _status(case_id, note, meta, SuggestionStatus.UNAVAILABLE, reason)
 
 
def get_suggestion(
    case_id: str,
    note: SourceEvidence,
    settings: Settings,
    caller: Caller = call_model,
    sleep: Callable[[float], None] = time.sleep,
) -> CaseSuggestion:
    if settings.ai_mode == "recorded":
        return read_recorded(case_id, note, settings)
 
    key = f"{note.note_id}:{settings.model}:{settings.prompt_version}"
    cache = load_cache(settings.cache_path)
    if key in cache:
        meta = CallMetadata(
            "cached",
            settings.model,
            settings.prompt_version,
            0,
            0,
            "cache",
            "reused from an earlier successful run",
        )
        return interpret_reply(cache[key], case_id, note, meta)
 
    prompt = build_prompt(note)
    try:
        reply = call_with_retry(
            lambda: caller(prompt, settings),
            max_attempts=settings.retry_max_attempts,
            base=settings.retry_base_seconds,
            cap=settings.retry_cap_seconds,
            rng=random.Random(),
            sleep=sleep,
        )
    except LlmTimeout:
        return _unavailable(
            case_id, note, settings, f"model timed out after {settings.retry_max_attempts} attempts"
        )
    except LlmRateLimited:
        return _unavailable(
            case_id, note, settings, f"rate limited after {settings.retry_max_attempts} attempts"
        )
    except LlmError as error:
        return _unavailable(case_id, note, settings, str(error))
 
    meta = CallMetadata(
        "live",
        reply.model,
        settings.prompt_version,
        reply.input_tokens,
        reply.output_tokens,
        reply.finish_reason,
    )
    suggestion = interpret_reply(reply.text, case_id, note, meta)
    if suggestion.status in (SuggestionStatus.OK, SuggestionStatus.ABSTAINED):
        cache[key] = reply.text  # only valid, usable replies are kept for reuse
        write_json_atomic(settings.cache_path, cache)
    return suggestion
