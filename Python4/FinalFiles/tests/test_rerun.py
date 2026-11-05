"""A rerun of the same batch does not repeat business work."""
 
from collections.abc import Callable
from pathlib import Path
 
from meridian_workbench.config import Settings
from meridian_workbench.llm_client import LlmReply
from meridian_workbench.pipeline import run_batch
 
REPLY = (
    '{"issue_family": "ADDRESS_CONFIRMATION", "summary": "Held at the depot.", '
    '"evidence_span": "awaiting address confirmation", "review_required": false}'
)
 
 
def test_rerun_same_batch_does_not_duplicate(
    settings_for: Callable[..., Settings], data_dir: Path
) -> None:
    calls: list[str] = []
 
    def counting(prompt: str, settings: Settings) -> LlmReply:
        calls.append(prompt)
        return LlmReply(REPLY, "test-model", 10, 5, "end_turn")
 
    settings = settings_for()
    first = run_batch(data_dir, settings, caller=counting)
    calls_after_first = len(calls)
    assert calls_after_first == 3  # three flagged cases have a note
 
    second = run_batch(data_dir, settings, caller=counting)
    assert len(calls) == calls_after_first  # no new model calls on the rerun
    assert second["batch_id"] == first["batch_id"]
    batches = list((settings.output_dir / "batches").iterdir())
    assert len(batches) == 1  # still one folder for one batch
 
    log = (batches[0] / "attempts.log").read_text(encoding="utf-8").splitlines()
    assert len(log) == 2
    assert log[1].endswith("reused finished batch; no work repeated")
