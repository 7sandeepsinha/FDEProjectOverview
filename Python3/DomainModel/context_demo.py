"""Step 1: composition. A CaseContext HAS a case and its linked records.

Run it with: python context_demo.py
"""

from datetime import date

from domain import (
    CaseContext,
    InventoryInfo,
    OrderStatus,
    ShipmentInfo,
    SourceEvidence,
    SupportCase,
)

# The real class data for three cases, already loaded into typed records.
cases = [
    SupportCase("C-1002", "O-5002", OrderStatus.SHIPPED, date(2025, 3, 7)),
    SupportCase("C-1004", "O-5004", OrderStatus.PROCESSING, date(2025, 3, 8)),
    SupportCase("C-1007", "O-5007", OrderStatus.CANCELLED, date(2025, 3, 5)),
]
# shipments.csv has no row for O-5004 (still processing) or O-5007 (cancelled), on purpose.
shipments = {"O-5002": ShipmentInfo("CARRIER_A", "HELD_AT_DEPOT", date(2025, 3, 8))}
inventory = {
    "O-5002": InventoryInfo("SKU-102", 3),
    "O-5004": InventoryInfo("SKU-204", 0),
    "O-5007": InventoryInfo("SKU-107", 9),
}
notes = [SourceEvidence("N-01", "C-1002", "Held at depot awaiting address confirmation")]

contexts = []
for case in cases:
    contexts.append(
        CaseContext(
            case=case,
            shipment=shipments.get(case.order_id),  # None when there is no row
            inventory=inventory.get(case.order_id),
            notes=tuple(n for n in notes if n.case_id == case.case_id),
        )
    )

for context in contexts:
    # The optional parts must be checked for None before use. mypy insists on it.
    if context.shipment is None:
        where = "no shipment yet"
    else:
        where = f"{context.shipment.carrier}, {context.shipment.shipment_status}"
    stock = context.inventory.units_on_hand if context.inventory else "unknown"
    print(f"{context.case.case_id}: {where}; stock {stock}; notes {len(context.notes)}")