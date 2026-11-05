"""Link each case to its shipment, inventory and note evidence."""
 
from meridian_workbench.domain import (
    CaseContext,
    InventoryInfo,
    ShipmentInfo,
    SourceEvidence,
    SupportCase,
)
 
 
def build_contexts(
    cases: list[SupportCase],
    notes: list[SourceEvidence],
    shipments: dict[str, ShipmentInfo],
    inventory: dict[str, InventoryInfo],
) -> list[CaseContext]:
    notes_by_case: dict[str, list[SourceEvidence]] = {}
    for note in notes:
        notes_by_case.setdefault(note.case_id, []).append(note)
 
    return [
        CaseContext(
            case=case,
            shipment=shipments.get(case.order_id),
            inventory=inventory.get(case.order_id),
            notes=tuple(notes_by_case.get(case.case_id, [])),
        )
        for case in cases
    ]
