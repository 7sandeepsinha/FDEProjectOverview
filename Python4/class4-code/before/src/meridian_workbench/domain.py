"""The Workbench vocabulary. Facts, evidence and suggestions are different types."""
 
from dataclasses import dataclass, field
from datetime import date
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
    source: str
    row_number: int
    raw: str
    reason: str
 
 
@dataclass
class CaseBatch:
    """What loading a case file gives back: the good rows and the rejected ones."""
 
    cases: list[SupportCase] = field(default_factory=list)
    rejected: list[RejectedRecord] = field(default_factory=list)
 
 
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
    mode: str  # "recorded", "live" or "recorded_fallback"
    model: str
    prompt_version: str
    input_tokens: int
    output_tokens: int
    finish_reason: str
    fallback_reason: str | None = None
 
 
@dataclass(frozen=True)
class CaseSuggestion:
    """What a model suggests about one case. It must always name its case and its note."""
 
    case_id: str
    source_note_id: str
    issue_family: IssueFamily | None = None
    summary: str | None = None
    evidence_span: str | None = None
    review_required: bool = True
    abstained: bool = False
    abstain_reason: str | None = None
    warnings: tuple[str, ...] = ()
    meta: CallMetadata | None = None
 
    def __post_init__(self) -> None:
        if not self.case_id or not self.source_note_id:
            raise ValueError("A suggestion must keep its case_id and source_note_id")
