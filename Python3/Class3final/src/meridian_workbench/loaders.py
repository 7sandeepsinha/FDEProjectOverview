"""Read the raw files and turn each row into a typed record, or a rejected record."""
 
import csv
import json
from datetime import date
from pathlib import Path
 
from meridian_workbench.domain import (
    CaseBatch,
    InventoryInfo,
    OrderStatus,
    RejectedRecord,
    ShipmentInfo,
    SourceEvidence,
    SupportCase,
)
 
 
def load_cases(path: Path) -> CaseBatch:
    batch = CaseBatch()
    with open(path, newline="", encoding="utf-8") as f:
        for row_number, row in enumerate(csv.DictReader(f), start=2):
            try:
                batch.cases.append(
                    SupportCase(
                        case_id=row["case_id"],
                        order_id=row["order_id"],
                        order_status=OrderStatus(row["order_status"]),
                        promised_date=date.fromisoformat(row["promised_date"]),
                    )
                )
            except ValueError as error:
                batch.rejected.append(
                    RejectedRecord(path.name, row_number, str(dict(row)), str(error))
                )
    return batch
 
 
def load_notes(path: Path) -> list[SourceEvidence]:
    with open(path, encoding="utf-8") as f:
        return [SourceEvidence(n["note_id"], n["case_id"], n["text"]) for n in json.load(f)]
 
 
def load_shipments(path: Path) -> dict[str, ShipmentInfo]:
    with open(path, newline="", encoding="utf-8") as f:
        return {
            row["order_id"]: ShipmentInfo(
                row["carrier"], row["shipment_status"], date.fromisoformat(row["last_scan_date"])
            )
            for row in csv.DictReader(f)
        }
 
 
def load_inventory(path: Path) -> dict[str, InventoryInfo]:
    with open(path, newline="", encoding="utf-8") as f:
        return {
            row["order_id"]: InventoryInfo(row["sku"], int(row["units_on_hand"]))
            for row in csv.DictReader(f)
        }
