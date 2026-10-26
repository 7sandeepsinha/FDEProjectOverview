#   Path      a file or folder location that works the same on Mac and Windows

from pathlib import Path

# --------------------------------------------------------------------------------------
# STEP 1: THE SETTINGS AND THE RULE, WRITTEN AT THE TOP
# --------------------------------------------------------------------------------------
# Names in ALL_CAPS are CONSTANTS: values set once and never changed while the program
# runs. Keeping them at the top means every important value is in one place.

DATA_DIR = Path("data")
# Where the input files live. "data" is a RELATIVE path: it means "a folder called data
# inside whatever folder the terminal is standing in". So the program only works when
# you start it from the right folder. Anywhere else, you get FileNotFoundError.
# (Class 2, Section 1 shows this failing on purpose. Section 7 fixes it.)

OUTPUT_DIR = Path("outputs")
# Where the report gets written. The program creates this folder if it is missing.

BATCH_DATE = date(2025, 3, 10)
# The "today" the report is calculated for: 10 March 2025.
# Why a fixed date and not the real today? The real today changes every day, so the
# same data would give a different report tomorrow. A fixed date makes the result
# REPRODUCIBLE: everyone who runs it gets exactly the same answer.
# (Class 2, Section 7 moves this into a settings file, so you can change the date
#  without editing code.)

# --------------------------------------------------------------------------------------
# STEP 6: RUN EVERYTHING, IN ORDER
# --------------------------------------------------------------------------------------
# main() is the conductor. It does no thinking of its own; it calls the other functions
# in the right order: load, decide, save, report.


def main():
    # 6a. Load both files. Path / "cases.csv" joins folder and file name: data/cases.csv
    cases = load_cases(DATA_DIR / "cases.csv")
    notes = load_notes(DATA_DIR / "notes.json")

    # 6b. Build a quick lookup from case ID to its note, like a phone book. Without it,
    # every case would have to search the whole list of notes for its own.
    # Afterwards:  {"C-1002": <note N-01>, "C-1005": <note N-02>, "C-1006": <note N-03>}
    # (If a case had two notes, the later one would replace the earlier one. Our data
    #  has at most one note per case.)
    notes_by_case = {}
    for note in notes:
        notes_by_case[note["case_id"]] = note

    # 6c. Apply the rule to every case. "for case in cases" repeats the indented lines
    # once per case, with "case" holding the current row each time round.
    results = []
    case_ids = []
    for case in cases:
        # .get(...) looks up the note and gives back None if this case has none.
        # (Square brackets, notes_by_case[...], would crash on a missing case instead.)
        note = notes_by_case.get(case["case_id"])
        # Add this case's row to the report, and remember its ID for the checks in 6d.
        results.append(build_result(case, note, BATCH_DATE))
        case_ids.append(case["case_id"])

    # 6d. Two safety checks before saving anything:
    #   - every case produced exactly one result (nothing lost, nothing doubled)
    #   - no case ID appears twice: set(...) drops duplicates, so if the count shrinks,
    #     there was a duplicate
    # (Class 2 swaps these asserts for real errors. Python can be started with a switch
    #  that skips every assert, and these checks must never be skipped.)
    assert len(results) == len(cases)
    assert len(set(case_ids)) == len(case_ids)

    # 6e. Save the full report.
    #   exist_ok=True  "fine if the folder already exists"
    #   "w"            open for writing; replaces any older report
    #   indent=2       spreads the JSON over many lines so a human can read it
    OUTPUT_DIR.mkdir(exist_ok=True)
    with open(OUTPUT_DIR / "attention_report.json", "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)

    # 6f. Print a short summary for the ops lead: one line per flagged case, then a
    # count. "flagged_count += 1" is short for "flagged_count = flagged_count + 1".
    # (On a date when a case is 1 day late it prints "(1 days)". That small wording
    #  slip is left alone on purpose: fixing it would change the output, and a tidy-up
    #  of the code should never change what the program prints.)
    flagged_count = 0
    for r in results:
        if r["needs_attention"]:
            flagged_count += 1
            print(f"{r['case_id']}: {r['reason']} ({r['days_overdue']} days)")
    print(f"{flagged_count} of {len(results)} cases need attention")
