"""The golden set is data we rely on, so it gets its own checks."""
 
from pathlib import Path
 
from meridian_workbench.config import load_settings
from meridian_workbench.golden import load_golden, summarize_scores
 
REQUIRED_KINDS = {"CLEAR", "RULE_ONLY", "AMBIGUOUS", "INSUFFICIENT", "ABSTAIN"}
 
 
def test_golden_set_has_8_to_10_items_and_every_kind() -> None:
    items = load_golden(load_settings().golden_dir / "golden_set.json")
    assert 8 <= len(items) <= 10
    assert {item.kind for item in items} == REQUIRED_KINDS
    assert len({item.golden_id for item in items}) == len(items)
 
 
def test_expected_evidence_is_quoted_from_the_note() -> None:
    items = load_golden(load_settings().golden_dir / "golden_set.json")
    for item in items:
        if item.expected_evidence_span is not None:
            assert item.expected_evidence_span in item.note.text
 
 
def test_abstain_items_expect_no_family() -> None:
    items = load_golden(load_settings().golden_dir / "golden_set.json")
    for item in items:
        if item.should_abstain:
            assert item.acceptable_issue_families == ()
 
 
def test_score_summary_counts_hand_marks(tmp_path: Path) -> None:
    sheet = tmp_path / "scores.csv"
    sheet.write_text(
        "golden_id,kind,issue_family_correct,evidence_grounded,unsupported_claims,"
        "abstention_correct,comment\n"
        "G-01,CLEAR,Y,Y,0,NA,\n"
        "G-07,CLEAR,Y,Y,1,NA,weather not in note\n"
        "G-09,INSUFFICIENT,N,N,0,N,should have abstained\n"
        "G-04,RULE_ONLY,NA,NA,NA,NA,no model call\n",
        encoding="utf-8",
    )
    summary = summarize_scores(sheet)
    assert summary["issue_family_correct"] == "2 of 3"
    assert summary["evidence_grounded"] == "2 of 3"
    assert summary["abstention_correct"] == "0 of 1"
    assert summary["unsupported_claims"] == "1"
