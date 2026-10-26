from meridian_workbench.rules import days_overdue, needs_attention

# --------------------------------------------------------------------------------------
# STEP 4: WRITE DOWN THE VERDICT, WITH EVIDENCE
# --------------------------------------------------------------------------------------
# For one case, build one row of the report. The ops lead asked for EVIDENCE, so each
# row says not just "late" but exactly which facts made it late.


def build_result(case, note, as_of):
    # "Unpacking": the rule hands back two values, and we catch them in two names.
    flag, reason = needs_attention(case, as_of)

    # How late is it? Start at 0 and only calculate when the case is flagged, so cases
    # that are on time or closed always show 0 days.
    days = 0
    if flag:
        days = days_overdue(case["promised_date"], as_of)

    # A case may or may not have a note. When there is none, main() passes in None,
    # Python's word for "nothing here". "if note:" is false for None, so we only ask for
    # note["note_id"] when a note really exists. (Asking None for a label would crash.)
    note_id = None
    if note:
        note_id = note["note_id"]

    # The evidence sentence. An F-STRING (f"...") fills in the values in {curly braces}.
    # as_of.isoformat() turns the date back into text: "2025-03-10".
    # Two strings side by side inside round brackets are glued into one string; this
    # just keeps long lines short. For C-1002 this produces:
    #     "Status SHIPPED, promised 2025-03-07, 3 days overdue as of 2025-03-10"
    if flag:
        evidence = (
            f"Status {case['order_status']}, promised {case['promised_date']}, "
            f"{days} days overdue as of {as_of.isoformat()}"
        )
    else:
        # A case that is NOT flagged still gets evidence, so anyone can see why it was
        # left out. For C-1007:
        #     "Not flagged (CLOSED). Status CANCELLED, promised 2025-03-05"
        evidence = (
            f"Not flagged ({reason}). Status {case['order_status']}, "
            f"promised {case['promised_date']}"
        )

    # One dictionary = one row of the report. Each label says what its value means.
    return {
        "case_id": case["case_id"],              # copied from the input
        "order_id": case["order_id"],            # copied from the input
        "order_status": case["order_status"],    # copied from the input
        "promised_date": case["promised_date"],  # copied from the input
        "batch_date": as_of.isoformat(),         # the "today" used, as text
        "needs_attention": flag,                 # the verdict: True or False
        "reason": reason,                        # OVERDUE_NOT_CLOSED, CLOSED or ON_TIME
        "days_overdue": days,                    # whole days late (0 if not flagged)
        "evidence": evidence,                    # the sentence a human can check
        "source_note_id": note_id,               # this case's note, or None
        # True only when the case is flagged AND has a note: the cases where a person
        # should read the free-text note to understand what went wrong. In Class 3 an AI
        # model helps read these notes, but it only SUGGESTS; the rule above decides.
        "needs_interpretation": flag and note is not None,
    }

