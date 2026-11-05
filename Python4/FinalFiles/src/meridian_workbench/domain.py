"""The Workbench vocabulary. Facts, evidence, decisions and suggestions are different types."""
 
from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal
from enum import StrEnum
 
 
class OrderStatus(StrEnum):
    PROCESSING = "PROCESSING"
    SHIPPED = "SHIPPED"
    DELIVERED = "DELIVERED"
    CANCELLED = "CANCELLED"
 
 
class AttentionReason(StrEnum):
    CLOSED = "CLOSED"
    OVERDUE_NOT_CLOSED = "OVERDUE_NOT_CLOSED"
    ON_TIME = "ON_TIME"
 
 
class IssueFamily(StrEnum):
    ADDRESS_CONFIRMATION = "ADDRESS_CONFIRMATION"
    FAILED_DELIVERY_ATTEMPT = "FAILED_DELIVERY_ATTEMPT"
    STOCK_SHORTAGE = "STOCK_SHORTAGE"
    CARRIER_DELAY = "CARRIER_DELAY"
    DAMAGED_IN_TRANSIT = "DAMAGED_IN_TRANSIT"
 
 
class RejectCategory(StrEnum):
    MALFORMED = "MALFORMED"  # a row or note we cannot read
    RULE_FAILURE = "RULE_FAILURE"  # readable, but it breaks a business rule
    DUPLICATE = "DUPLICATE"  # a repeat of a key we already kept
    MISSING_SOURCE = "MISSING_SOURCE"
 
 
class SuggestionStatus(StrEnum):
    OK = "OK"  # a valid reply that passed the shape check
    ABSTAINED = "ABSTAINED"  # the model said the note is not enough
    INVALID_REPLY = "INVALID_REPLY"  # the reply could not be read or had the wrong shape
    UNAVAILABLE = "UNAVAILABLE"  # no usable reply: timeout, rate limit, failure, or no key
 
 
# ---- Facts and evidence: read from files, never changed ----
 
 
@dataclass(frozen=True)
class SupportCase:
    """One row of cases.csv. One case, one order, one promise."""
 
    case_id: str
    order_id: str
    order_status: OrderStatus
    promised_date: date
 
 
@dataclass(frozen=True)
class SourceEvidence:
    """One free-text note, exactly as written, linked to one case."""
 
    note_id: str
    case_id: str
    text: str
 
 
@dataclass(frozen=True)
class RejectedRecord:
    """A quarantined record: where it came from, what it said, and why it was not used."""
 
    source: str
    row_number: int
    category: RejectCategory
    raw: str
    reason: str
 
 
@dataclass
class Ledger:
    """The books for one source file. Every row read is either accepted or quarantined."""
 
    source: str
    input_rows: int = 0
    accepted: int = 0
    rejected: list[RejectedRecord] = field(default_factory=list)
 
    def reject(self, row_number: int, category: RejectCategory, raw: str, reason: str) -> None:
        self.rejected.append(RejectedRecord(self.source, row_number, category, raw, reason))
 
 
# ---- Decisions made by Python rules ----
 
 
@dataclass(frozen=True)
class AttentionDecision:
    case_id: str
    needs_attention: bool
    reason: AttentionReason
    days_overdue: int
 
 
# ---- Linked records: a case has these, it is not a kind of them ----
 
 
@dataclass(frozen=True)
class ShipmentInfo:
    carrier: str
    shipment_status: str
    last_scan_date: date
 
 
@dataclass(frozen=True)
class InventoryInfo:
    sku: str
    units_on_hand: int
    unit_value: Decimal
 
 
@dataclass(frozen=True)
class CaseContext:
    """A case plus everything linked to it. It has parts; it is not a kind of case."""
 
    case: SupportCase
    shipment: ShipmentInfo | None = None
    inventory: InventoryInfo | None = None
    notes: tuple[SourceEvidence, ...] = ()
 
 
# ---- Suggestions made by a model: never facts ----
 
 
@dataclass(frozen=True)
class CallMetadata:
    mode: str  # "recorded", "live" or "cached"
    model: str
    prompt_version: str
    input_tokens: int
    output_tokens: int
    finish_reason: str
    detail: str | None = None
 
 
@dataclass(frozen=True)
class CaseSuggestion:
    """What a model suggests about one case. It always names its case and its note."""
 
    case_id: str
    source_note_id: str
    status: SuggestionStatus = SuggestionStatus.OK
    issue_family: IssueFamily | None = None
    summary: str | None = None
    evidence_span: str | None = None
    review_required: bool = True
    reason: str | None = None  # why the status is not OK, in one sentence
    warnings: tuple[str, ...] = ()
    meta: CallMetadata | None = None
 
    def __post_init__(self) -> None:
        if not self.case_id or not self.source_note_id:
            raise ValueError("A suggestion must keep its case_id and source_note_id")
