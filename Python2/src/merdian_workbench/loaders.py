"""Read the raw case files."""

#   csv       reads CSV files: a spreadsheet saved as plain text
#   json      reads and writes JSON: lists and labelled values saved as text

import csv
import json

# --------------------------------------------------------------------------------------
# STEP 2: READ THE FILES
# --------------------------------------------------------------------------------------
# "def" defines a FUNCTION: a named, reusable set of steps. The names in brackets are
# its PARAMETERS, the inputs you hand it. "return" hands the answer back to the caller.
# Think of a function as a recipe card: a name on top, ingredients listed, one dish out.

def load_cases(path):
    # "with open(...) as f" opens the file and guarantees it is closed afterwards, even
    # if something goes wrong. Like borrowing a library book from a librarian who always
    # takes it back.
    #   newline=""        lets the csv tool handle line endings itself (its own advice)
    #   encoding="utf-8"  reads the text the same way on every computer
    with open(path, newline="", encoding="utf-8") as f:
        # csv.DictReader reads the first row as column names, then turns every other row
        # into a DICTIONARY (label -> value). One row of cases.csv becomes:
        #     {"case_id": "C-1002", "order_id": "O-5002",
        #      "order_status": "SHIPPED", "promised_date": "2025-03-07"}
        # Every value is TEXT, even the date. STEP 3 turns it into a real date.
        #
        # list(...) collects all the rows NOW, while the file is still open. DictReader
        # only reads a row when asked, and the file closes as soon as this block ends.
        return list(csv.DictReader(f))


def load_notes(path):
    with open(path, encoding="utf-8") as f:
        # json.load turns JSON text into Python data. notes.json is a LIST of notes,
        # and each note is a dictionary:
        #     [{"note_id": "N-01", "case_id": "C-1002",
        #       "text": "Held at depot awaiting address confirmation"}, ...]
        # Notes are free text written by people. Only 3 of the 7 cases have one.
        return json.load(f)