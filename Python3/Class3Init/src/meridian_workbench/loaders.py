"""Read the raw case files."""
 
import csv
import json
 
 
def load_cases(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))
 
 
def load_notes(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)
