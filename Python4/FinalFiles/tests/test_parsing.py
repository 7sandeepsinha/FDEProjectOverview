"""Defensive parsing: each parser accepts one meaning and refuses everything else with a reason."""
 
from decimal import Decimal
 
import pytest
 
from meridian_workbench.domain import OrderStatus
from meridian_workbench.errors import MalformedRecord
from meridian_workbench.parsing import parse_amount, parse_date, parse_status, parse_units
 
 
def test_date_refuses_the_basic_iso_form_and_day_first_text() -> None:
    assert parse_date("2025-03-07").isoformat() == "2025-03-07"
    with pytest.raises(MalformedRecord):
        parse_date("20250307")
    with pytest.raises(MalformedRecord):
        parse_date("07/03/2025")
 
 
def test_amount_needs_exactly_two_decimal_places() -> None:
    assert parse_amount("19.99") == Decimal("19.99")
    for refused in ("1.250", "1,250.00", "NaN", "Infinity", "-3.00"):
        with pytest.raises(MalformedRecord):
            parse_amount(refused)
 
 
def test_units_are_whole_non_negative_numbers() -> None:
    assert parse_units("14") == 14
    for refused in ("-3", "1,000", "2.5", ""):
        with pytest.raises(MalformedRecord):
            parse_units(refused)
 
 
def test_status_trims_spaces_but_not_case() -> None:
    assert parse_status("  SHIPPED ") is OrderStatus.SHIPPED
    with pytest.raises(MalformedRecord):
        parse_status("shipped")
