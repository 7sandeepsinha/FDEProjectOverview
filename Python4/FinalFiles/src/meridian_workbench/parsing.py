"""Defensive parsing: read a value only when its meaning is certain, otherwise refuse it clearly."""
 
import re
from datetime import date
from decimal import Decimal, InvalidOperation
 
from meridian_workbench.domain import OrderStatus
from meridian_workbench.errors import MalformedRecord
 
DATE_SHAPE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
AMOUNT_SHAPE = re.compile(r"^\d+\.\d{2}$")  # money: digits, a dot, exactly two decimal places
UNITS_SHAPE = re.compile(r"^\d+$")  # a whole, non-negative count
 
 
def require_text(raw: str | None, field: str) -> str:
    """A field must exist and not be blank. Surrounding spaces are removed."""
    if raw is None or not raw.strip():
        raise MalformedRecord(f"{field} is empty")
    return raw.strip()
 
 
def parse_date(raw: str | None, field: str = "promised_date") -> date:
    """Only YYYY-MM-DD is accepted. 07/03/2025 could mean 7 March or 3 July, so we refuse it."""
    text = require_text(raw, field)
    if not DATE_SHAPE.match(text):
        raise MalformedRecord(f"{field} {text!r} is not YYYY-MM-DD")
    try:
        return date.fromisoformat(text)
    except ValueError as error:
        raise MalformedRecord(f"{field} {text!r} is not a real calendar date") from error
 
 
def parse_units(raw: str | None, field: str = "units_on_hand") -> int:
    text = require_text(raw, field)
    if not UNITS_SHAPE.match(text):
        raise MalformedRecord(f"{field} {text!r} is not a whole number of zero or more")
    return int(text)
 
 
def parse_amount(raw: str | None, field: str = "unit_value") -> Decimal:
    """Money in our data contract: a dot, exactly two decimal places, no thousands separator."""
    text = require_text(raw, field)
    if not AMOUNT_SHAPE.match(text):
        raise MalformedRecord(
            f"{field} {text!r} must look like 19.99 (two decimal places, no commas)"
        )
    try:
        value = Decimal(text)
    except InvalidOperation as error:  # the shape check should catch this first; belt and braces
        raise MalformedRecord(f"{field} {text!r} is not a number") from error
    if not value.is_finite():
        raise MalformedRecord(f"{field} {text!r} is not a finite number")
    return value
 
 
def parse_status(raw: str | None, field: str = "order_status") -> OrderStatus:
    text = require_text(raw, field)
    try:
        return OrderStatus(text)
    except ValueError as error:
        allowed = ", ".join(status.value for status in OrderStatus)
        raise MalformedRecord(f"{field} {text!r} is not one of {allowed}") from error
