
#   date      a calendar date you can subtract and compare
from datetime import date

# --------------------------------------------------------------------------------------
# STEP 3: THE RULE (the heart of the program)
# --------------------------------------------------------------------------------------
# These two functions are PURE: they use only what you hand them. No files, no internet,
# no hidden state. That is what makes them easy to check with made-up examples (STEP 5).


def days_overdue(promised_date_text, as_of):
    """Whole days between the promised date and the batch date."""
    # Text "2025-03-07" becomes a real date. fromisoformat expects year-month-day.
    promised = date.fromisoformat(promised_date_text)
    # Subtracting two dates gives the gap between them; .days is that gap in whole days.
    #   promised 7 March,  as_of 10 March  ->   3   (3 days late)
    #   promised 10 March, as_of 10 March  ->   0   (due today, not late yet)
    #   promised 12 March, as_of 10 March  ->  -2   (due in 2 days)
    return (as_of - promised).days


def needs_attention(case, as_of):
    """Return (flag, reason). Python decides this, never the model."""
    # This returns TWO things at once, as a TUPLE: a yes/no FLAG and a REASON code.
    # Like a triage nurse's note: "see now? yes, because: fever". The reason is the
    # evidence for the flag, so nobody has to trust a bare yes/no.
    #
    # "Python decides, never the model": from Class 3, an AI model will help read the
    # notes. It may SUGGEST what a note means. It never makes this decision.
    #
    # The ORDER of the checks matters. "Closed" is checked first, so a cancelled order
    # promised long ago (C-1007) counts as CLOSED, not as late.

    # Check 1: is the order finished? "in" asks the set from STEP 1.
    if case["order_status"] in CLOSED_STATUSES:
        return False, "CLOSED"

    # Check 2: has the promised date passed? "> 0" means at least one whole day late,
    # so a case due today (0 days) is not flagged yet.
    if days_overdue(case["promised_date"], as_of) > 0:
        return True, "OVERDUE_NOT_CLOSED"

    # Neither: still open, but not late. "return" leaves the function at the first
    # answer, so we only reach this line when both checks above said no.
    return False, "ON_TIME"
