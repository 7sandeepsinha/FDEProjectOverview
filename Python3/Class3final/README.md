# Meridian Case Intake Workbench
 
Which customer cases need attention today, and what is the evidence? This program reads cases, linked shipment and inventory records and short notes, applies one clear rule in Python, and writes a report. A model may add a labelled suggestion beside the evidence. It never changes a fact.
 
## Requirements
 
- Python 3.11 or newer
- Git
 
## Set up
 
macOS or Linux:
 
```
git clone https://github.com/<your-username>/meridian-workbench.git
cd meridian-workbench
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```
 
Windows PowerShell:
 
```
git clone https://github.com/<your-username>/meridian-workbench.git
cd meridian-workbench
py -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```
 
If PowerShell blocks the activation script, run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once and try again.
 
## Run
 
```
python -m meridian_workbench
```
 
Expected output:
 
```
C-1002: OVERDUE_NOT_CLOSED (3 days)
    suggestion (recorded): ADDRESS_CONFIRMATION, review_required=False
C-1004: OVERDUE_NOT_CLOSED (2 days)
C-1005: OVERDUE_NOT_CLOSED (4 days)
    suggestion (recorded): ABSTAINED, review_required=True
C-1006: OVERDUE_NOT_CLOSED (2 days)
    suggestion (recorded): FAILED_DELIVERY_ATTEMPT, review_required=True
4 of 7 cases need attention
```
 
The full report is written to `outputs/attention_report.json`. Facts and the model's suggestion are stored under separate keys.
 
## Check
 
```
pytest
mypy
ruff check .
```
 
Success looks like `26 passed`, `Success: no issues found` and `All checks passed!`.
 
## Settings
 
Settings live in `config/settings.toml`. To run for a different batch date without editing any file:
 
macOS or Linux: `MERIDIAN_BATCH_DATE=2025-03-13 python -m meridian_workbench`
 
Windows PowerShell: `$env:MERIDIAN_BATCH_DATE = "2025-03-13"` and then run the command above.
 
For local overrides, copy `.env.example` to `.env`. Never commit `.env`.
 
## Using a live model (optional)
 
The default mode is `recorded`: saved responses from `fixtures/` are used, so no key or internet is needed.
 
To make one bounded call per flagged note, put your own key in `.env` as `MERIDIAN_LLM_API_KEY=...` and set `MERIDIAN_AI_MODE=live`. If the key is missing or the call fails, the Workbench falls back to the recorded response and says so in the report (`recorded_fallback`).
 
## Golden set
 
`golden/golden_set.json` holds 10 hand-written examples. Run them and score the answers by hand:
 
```
python -m meridian_workbench.golden run
python -m meridian_workbench.golden score
```
 
Fill in `golden/scoring_baseline.csv` between the two commands. `blank-sheet` creates a fresh empty sheet and overwrites the old one, so use it once.
 
## Project layout
 
```
src/meridian_workbench/   the program: domain types, loaders, rules, results, ai_client, llm_client
tests/                    pytest checks for the domain, loading, rules, AI step and golden set
data/                     cases.csv, notes.json, shipments.csv, inventory.csv
config/                   settings.toml
fixtures/                 recorded model responses, rows with deliberate errors
golden/                   the golden set and the hand-scoring sheet
docs/                     terminology.md, the agreed meaning of case, evidence and fact
outputs/                  generated reports (not committed)
```
