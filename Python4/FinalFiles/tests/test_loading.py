"""Case grain and source linkage, checked on the real data files and on the fixtures."""
 
from meridian_workbench.config import load_settings
from meridian_workbench.context import build_contexts
from meridian_workbench.domain import RejectCategory
from meridian_workbench.loaders import load_cases, load_inventory, load_notes, load_shipments
 
 
def test_one_row_per_case() -> None:
    settings = load_settings()
    rows, ledger = load_cases(settings.data_dir / "cases.csv")
    ids = [case.case_id for _, case in rows]
    assert len(ids) == 7
    assert len(set(ids)) == len(ids)
    assert ledger.input_rows == 7
    assert ledger.rejected == []
 
 
def test_every_note_points_at_a_real_case() -> None:
    settings = load_settings()
    rows, _ = load_cases(settings.data_dir / "cases.csv")
    case_ids = {case.case_id for _, case in rows}
    notes, ledger = load_notes(settings.data_dir / "notes.json")
    assert notes
    assert ledger.rejected == []
    assert all(note.case_id in case_ids for note in notes)
 
 
def test_context_links_notes_shipments_and_inventory() -> None:
    settings = load_settings()
    rows, _ = load_cases(settings.data_dir / "cases.csv")
    notes, _ = load_notes(settings.data_dir / "notes.json")
    shipments, _ = load_shipments(settings.data_dir / "shipments.csv")
    inventory, _ = load_inventory(settings.data_dir / "inventory.csv")
    contexts = build_contexts([case for _, case in rows], notes, shipments, inventory)
    by_case = {c.case.case_id: c for c in contexts}
    assert len(contexts) == len(rows)
    assert [n.note_id for n in by_case["C-1002"].notes] == ["N-01"]
    assert by_case["C-1002"].shipment is not None
    assert by_case["C-1002"].shipment.shipment_status == "HELD_AT_DEPOT"
    assert by_case["C-1004"].shipment is None  # still processing: nothing shipped yet
    assert by_case["C-1004"].inventory is not None
    assert by_case["C-1004"].inventory.units_on_hand == 0
    assert by_case["C-1001"].notes == ()
 
 
def test_bad_rows_become_rejected_records() -> None:
    settings = load_settings()
    rows, ledger = load_cases(settings.fixtures_dir / "cases_bad_rows.csv")
    assert [case.case_id for _, case in rows] == ["C-2001", "C-2004"]
    assert [r.row_number for r in ledger.rejected] == [3, 4]
    assert all(r.category is RejectCategory.MALFORMED for r in ledger.rejected)
    assert "RETURNED" in ledger.rejected[0].reason
    assert "07/03/2025" in ledger.rejected[1].reason
