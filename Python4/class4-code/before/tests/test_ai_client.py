"""The suggestion step: metadata, fallback, grounding and the case_id / source_note_id rule."""
 
import json
from dataclasses import replace
from pathlib import Path
 
from meridian_workbench.ai_client import Caller, build_prompt, get_suggestion
from meridian_workbench.config import Settings, load_settings
from meridian_workbench.domain import IssueFamily, SourceEvidence
from meridian_workbench.llm_client import LlmCallFailed, LlmReply, MissingApiKeyError
 
NOTE = SourceEvidence("N-01", "C-1002", "Held at depot awaiting address confirmation")
 
 
def live_settings() -> Settings:
    return replace(load_settings(), ai_mode="live", api_key="test-key-not-real")
 
 
def fake_reply(text: str) -> Caller:
    def caller(prompt: str, settings: Settings) -> LlmReply:
        assert NOTE.text in prompt
        return LlmReply(text, "test-model", 120, 40, "end_turn")
 
    return caller
 
 
def test_recorded_mode_needs_no_key() -> None:
    suggestion = get_suggestion("C-1002", NOTE, load_settings())
    assert suggestion.issue_family is IssueFamily.ADDRESS_CONFIRMATION
    assert suggestion.meta is not None and suggestion.meta.mode == "recorded"
 
 
def test_live_call_keeps_model_prompt_version_usage_and_finish_status() -> None:
    reply = json.dumps(
        {
            "issue_family": "ADDRESS_CONFIRMATION",
            "summary": "Held until the address is confirmed.",
            "evidence_span": "awaiting address confirmation",
            "review_required": False,
        }
    )
    suggestion = get_suggestion("C-1002", NOTE, live_settings(), fake_reply(reply))
    meta = suggestion.meta
    assert meta is not None
    assert (meta.mode, meta.model, meta.prompt_version) == ("live", "test-model", "v1")
    assert (meta.input_tokens, meta.output_tokens, meta.finish_reason) == (120, 40, "end_turn")
    assert suggestion.review_required is False
 
 
def test_missing_key_falls_back_to_recorded() -> None:
    def no_key(prompt: str, settings: Settings) -> LlmReply:
        raise MissingApiKeyError("MERIDIAN_LLM_API_KEY is not set")
 
    suggestion = get_suggestion("C-1002", NOTE, live_settings(), no_key)
    assert suggestion.meta is not None
    assert suggestion.meta.mode == "recorded_fallback"
    assert suggestion.meta.fallback_reason == "MERIDIAN_LLM_API_KEY is not set"
    assert suggestion.issue_family is IssueFamily.ADDRESS_CONFIRMATION
 
 
def test_failed_call_falls_back_to_recorded() -> None:
    def failing(prompt: str, settings: Settings) -> LlmReply:
        raise LlmCallFailed("APITimeoutError")
 
    suggestion = get_suggestion("C-1002", NOTE, live_settings(), failing)
    assert suggestion.meta is not None and suggestion.meta.mode == "recorded_fallback"
 
 
def test_ungrounded_evidence_forces_review() -> None:
    reply = json.dumps(
        {
            "issue_family": "ADDRESS_CONFIRMATION",
            "evidence_span": "made up quote",
            "review_required": False,
        }
    )
    suggestion = get_suggestion("C-1002", NOTE, live_settings(), fake_reply(reply))
    assert suggestion.review_required is True
    assert "evidence_span does not appear in the note" in suggestion.warnings
 
 
def test_unreadable_reply_becomes_an_abstention_that_keeps_its_ids() -> None:
    suggestion = get_suggestion("C-1002", NOTE, live_settings(), fake_reply("Sorry, I cannot help"))
    assert suggestion.abstained
    assert (suggestion.case_id, suggestion.source_note_id) == ("C-1002", "N-01")
 
 
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
 
 
def test_settings_repr_hides_the_key() -> None:
    assert "test-key-not-real" not in repr(live_settings())
 
 
def test_rules_file_stays_free_of_ai_code() -> None:
    rules = Path(__file__).resolve().parents[1] / "src" / "meridian_workbench" / "rules.py"
    text = rules.read_text(encoding="utf-8")
    for forbidden in ("ai_client", "llm_client", "anthropic", "config", "loaders"):
        assert forbidden not in text
