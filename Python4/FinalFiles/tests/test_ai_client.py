"""The suggestion step: statuses, metadata, grounding, cache and ID rules."""
 
import json
from collections.abc import Callable
from pathlib import Path
 
from meridian_workbench.ai_client import Caller, build_prompt, get_suggestion
from meridian_workbench.config import Settings, load_settings
from meridian_workbench.domain import IssueFamily, SourceEvidence, SuggestionStatus
from meridian_workbench.llm_client import LlmCallFailed, LlmReply, MissingApiKeyError
 
NOTE = SourceEvidence("N-01", "C-1002", "Held at depot awaiting address confirmation")
 
 
def fake_reply(text: str, calls: list[str] | None = None) -> Caller:
    def caller(prompt: str, settings: Settings) -> LlmReply:
        assert NOTE.text in prompt
        if calls is not None:
            calls.append(prompt)
        return LlmReply(text, "test-model", 120, 40, "end_turn")
 
    return caller
 
 
GOOD_REPLY = json.dumps(
    {
        "issue_family": "ADDRESS_CONFIRMATION",
        "summary": "Held until the address is confirmed.",
        "evidence_span": "awaiting address confirmation",
        "review_required": False,
    }
)
 
 
def test_recorded_mode_needs_no_key() -> None:
    suggestion = get_suggestion("C-1002", NOTE, load_settings())
    assert suggestion.issue_family is IssueFamily.ADDRESS_CONFIRMATION
    assert suggestion.meta is not None and suggestion.meta.mode == "recorded"
 
 
def test_live_call_keeps_model_prompt_version_usage_and_finish_status(
    settings_for: Callable[..., Settings],
) -> None:
    suggestion = get_suggestion(
        "C-1002", NOTE, settings_for(), fake_reply(GOOD_REPLY), sleep=lambda s: None
    )
    meta = suggestion.meta
    assert meta is not None
    assert (meta.mode, meta.model, meta.prompt_version) == ("live", "test-model", "v1")
    assert (meta.input_tokens, meta.output_tokens, meta.finish_reason) == (120, 40, "end_turn")
    assert suggestion.status is SuggestionStatus.OK
    assert suggestion.review_required is False
 
 
def test_missing_key_is_unavailable_not_invented(settings_for: Callable[..., Settings]) -> None:
    def no_key(prompt: str, settings: Settings) -> LlmReply:
        raise MissingApiKeyError("MERIDIAN_LLM_API_KEY is not set")
 
    suggestion = get_suggestion("C-1002", NOTE, settings_for(), no_key, sleep=lambda s: None)
    assert suggestion.status is SuggestionStatus.UNAVAILABLE
    assert suggestion.issue_family is None
    assert suggestion.reason == "MERIDIAN_LLM_API_KEY is not set"
 
 
def test_failed_call_is_unavailable_and_never_uses_recorded_answers(
    settings_for: Callable[..., Settings],
) -> None:
    def failing(prompt: str, settings: Settings) -> LlmReply:
        raise LlmCallFailed("APIConnectionError")
 
    suggestion = get_suggestion("C-1002", NOTE, settings_for(), failing, sleep=lambda s: None)
    assert suggestion.status is SuggestionStatus.UNAVAILABLE
    assert suggestion.issue_family is None
    assert suggestion.meta is not None and suggestion.meta.mode == "live"
 
 
def test_ungrounded_evidence_forces_review(settings_for: Callable[..., Settings]) -> None:
    reply = json.dumps(
        {
            "issue_family": "ADDRESS_CONFIRMATION",
            "summary": "Held at depot.",
            "evidence_span": "made up quote",
            "review_required": False,
        }
    )
    suggestion = get_suggestion(
        "C-1002", NOTE, settings_for(), fake_reply(reply), sleep=lambda s: None
    )
    assert suggestion.status is SuggestionStatus.OK
    assert suggestion.review_required is True
    assert "evidence_span does not appear in the note" in suggestion.warnings
 
 
def test_unreadable_reply_is_invalid_and_keeps_its_ids(
    settings_for: Callable[..., Settings],
) -> None:
    suggestion = get_suggestion(
        "C-1002", NOTE, settings_for(), fake_reply("Sorry, I cannot help"), sleep=lambda s: None
    )
    assert suggestion.status is SuggestionStatus.INVALID_REPLY
    assert (suggestion.case_id, suggestion.source_note_id) == ("C-1002", "N-01")
 
 
def test_unknown_family_is_invalid_not_guessed(settings_for: Callable[..., Settings]) -> None:
    reply = json.dumps({"issue_family": "WEATHER", "evidence_span": None})
    suggestion = get_suggestion(
        "C-1002", NOTE, settings_for(), fake_reply(reply), sleep=lambda s: None
    )
    assert suggestion.status is SuggestionStatus.INVALID_REPLY
    assert suggestion.issue_family is None
 
 
def test_successful_reply_is_reused_from_the_cache(settings_for: Callable[..., Settings]) -> None:
    calls: list[str] = []
    settings = settings_for()
    first = get_suggestion(
        "C-1002", NOTE, settings, fake_reply(GOOD_REPLY, calls), sleep=lambda s: None
    )
    second = get_suggestion(
        "C-1002", NOTE, settings, fake_reply(GOOD_REPLY, calls), sleep=lambda s: None
    )
    assert len(calls) == 1  # the second answer came from the cache, not from the model
    assert second.status is SuggestionStatus.OK
    assert second.issue_family == first.issue_family
    assert second.meta is not None and second.meta.mode == "cached"
 
 
def test_failures_are_never_cached(settings_for: Callable[..., Settings]) -> None:
    calls: list[str] = []
    settings = settings_for()
 
    def failing(prompt: str, s: Settings) -> LlmReply:
        calls.append(prompt)
        raise LlmCallFailed("APIConnectionError")
 
    get_suggestion("C-1002", NOTE, settings, failing, sleep=lambda s: None)
    get_suggestion("C-1002", NOTE, settings, failing, sleep=lambda s: None)
    assert len(calls) == 2
    assert not settings.cache_path.exists()
 
 
def test_every_recorded_suggestion_keeps_case_id_and_source_note_id() -> None:
    settings = load_settings()
    recorded = json.loads((settings.fixtures_dir / "recorded_responses.json").read_text("utf-8"))
    for note_id in recorded:
        note = SourceEvidence(note_id, "C-TEST", "text")
        suggestion = get_suggestion("C-TEST", note, settings)
        assert suggestion.case_id == "C-TEST"
        assert suggestion.source_note_id == note_id
 
 
def test_prompt_lists_the_allowed_families_and_the_abstain_instruction() -> None:
    prompt = build_prompt(NOTE)
    assert "STOCK_SHORTAGE" in prompt
    assert "Do not guess" in prompt
 
 
def test_settings_repr_hides_the_key(settings_for: Callable[..., Settings]) -> None:
    assert "test-key-not-real" not in repr(settings_for())
 
 
def test_rules_file_stays_free_of_ai_code() -> None:
    rules = Path(__file__).resolve().parents[1] / "src" / "meridian_workbench" / "rules.py"
    text = rules.read_text(encoding="utf-8")
    for forbidden in ("ai_client", "llm_client", "anthropic", "config", "loaders"):
        assert forbidden not in text
