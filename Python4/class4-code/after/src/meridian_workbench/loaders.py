"""Read each source file row by row. Every row is accepted, or quarantined with a reason."""
 
import csv
import json
from pathlib import Path
 
from meridian_workbench.domain import (
    InventoryInfo,
    Ledger,
    RejectCategory,
    ShipmentInfo,
    SourceEvidence,
    SupportCase,
)
from meridian_workbench.errors import MalformedRecord, UnreadableSource
from meridian_workbench.parsing import (
    parse_amount,
    parse_date,
    parse_status,
    parse_units,
    require_text,
)
 
 
def read_csv_rows(path: Path) -> list[tuple[int, dict[str, str | None]]]:
    """Each row with its line number. Line 1 is the header, so the first data row is line 2."""
    with open(path, newline="", encoding="utf-8") as f:
        return [(number, row) for number, row in enumerate(csv.DictReader(f), start=2)]
 
 
def load_cases(path: Path) -> tuple[list[tuple[int, SupportCase]], Ledger]:
    ledger = Ledger(path.name)
    rows: list[tuple[int, SupportCase]] = []
    for row_number, row in read_csv_rows(path):
        ledger.input_rows += 1
        try:
            case = SupportCase(
                case_id=require_text(row.get("case_id"), "case_id"),
                order_id=require_text(row.get("order_id"), "order_id"),
                order_status=parse_status(row.get("order_status")),
                promised_date=parse_date(row.get("promised_date")),
            )
        except MalformedRecord as problem:
            ledger.reject(row_number, RejectCategory.MALFORMED, str(dict(row)), str(problem))
            continue
        rows.append((row_number, case))
    ledger.accepted = len(rows)
    return rows, ledger
 
 
def load_notes(path: Path) -> tuple[list[SourceEvidence], Ledger]:
    """notes.json has no line numbers, so the row number is the item's position (1 is first)."""
    ledger = Ledger(path.name)
    notes: list[SourceEvidence] = []
    try:
        with open(path, encoding="utf-8") as f:
            items = json.load(f)
    except json.JSONDecodeError as error:
        raise UnreadableSource(f"{path.name} is not valid JSON: {error}") from error
    if not isinstance(items, list):
        raise UnreadableSource(f"{path.name} must hold a list of notes")
    for position, item in enumerate(items, start=1):
        ledger.input_rows += 1
        try:
            if not isinstance(item, dict):
                raise MalformedRecord("the note is not an object with fields")
            note = SourceEvidence(
                note_id=require_text(item.get("note_id"), "note_id"),
                case_id=require_text(item.get("case_id"), "case_id"),
                text=require_text(item.get("text"), "text"),
            )
        except MalformedRecord as problem:
            ledger.reject(position, RejectCategory.MALFORMED, json.dumps(item), str(problem))
            continue
        notes.append(note)
    ledger.accepted = len(notes)
    return notes, ledger
 
 
def load_shipments(path: Path) -> tuple[dict[str, ShipmentInfo], Ledger]:
    ledger = Ledger(path.name)
    shipments: dict[str, ShipmentInfo] = {}
    for row_number, row in read_csv_rows(path):
        ledger.input_rows += 1
        try:
            order_id = require_text(row.get("order_id"), "order_id")
            if order_id in shipments:
                ledger.reject(
                    row_number,
                    RejectCategory.DUPLICATE,
                    str(dict(row)),
                    f"order_id {order_id} already has a shipment; the first row is kept",
                )
                continue
            shipments[order_id] = ShipmentInfo(
                carrier=require_text(row.get("carrier"), "carrier"),
                shipment_status=require_text(row.get("shipment_status"), "shipment_status"),
                last_scan_date=parse_date(row.get("last_scan_date"), "last_scan_date"),
            )
        except MalformedRecord as problem:
            ledger.reject(row_number, RejectCategory.MALFORMED, str(dict(row)), str(problem))
    ledger.accepted = len(shipments)
    return shipments, ledger
 
 
def load_inventory(path: Path) -> tuple[dict[str, InventoryInfo], Ledger]:
    ledger = Ledger(path.name)
    inventory: dict[str, InventoryInfo] = {}
    for row_number, row in read_csv_rows(path):
        ledger.input_rows += 1
        try:
            order_id = require_text(row.get("order_id"), "order_id")
            if order_id in inventory:
                ledger.reject(
                    row_number,
                    RejectCategory.DUPLICATE,
                    str(dict(row)),
                    f"order_id {order_id} already has an inventory line; the first row is kept",
                )
                continue
            inventory[order_id] = InventoryInfo(
                sku=require_text(row.get("sku"), "sku"),
                units_on_hand=parse_units(row.get("units_on_hand")),
                unit_value=parse_amount(row.get("unit_value")),
            )
        except MalformedRecord as problem:
            ledger.reject(row_number, RejectCategory.MALFORMED, str(dict(row)), str(problem))
    ledger.accepted = len(inventory)
    return inventory, ledger
