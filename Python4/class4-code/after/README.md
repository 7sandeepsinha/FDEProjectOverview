# Meridian Case Intake Workbench
 
Which customer cases need attention today, and what is the evidence? This program reads cases, linked shipment and inventory records and short notes. It checks every row, sets aside the rows it cannot use with a reason, applies one clear rule in Python, and writes a report. A model may add a labelled suggestion beside the evidence. It never changes a fact.
 
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
 
Expected output (the attempt ID is different on every run):
 
```
cases.csv: input 7, accepted 7, quarantined 0, reconciled yes
notes.json: input 3, accepted 3, quarantined 0, reconciled yes
shipments.csv: input 5, accepted 5, quarantined 0, reconciled yes
inventory.csv: input 7, accepted 7, quarantined 0, reconciled yes
C-1002: OVERDUE_NOT_CLOSED (3 days)
    suggestion (recorded): ADDRESS_CONFIRMATION, review_required=False
C-1004: OVERDUE_NOT_CLOSED (2 days)
C-1005: OVERDUE_NOT_CLOSED (4 days)
    suggestion (recorded): ABSTAINED - The note refers to an earlier message and says nothing about the issue.
C-1006: OVERDUE_NOT_CLOSED (2 days)
    suggestion (recorded): FAILED_DELIVERY_ATTEMPT, review_required=True
4 of 7 cases need attention
batch B-1bf9b12a0999 (attempt 222ae48d-b3d0-4976-8468-cf0a31bbe7b4)
```
 
Each run writes to `outputs/batches/<batch id>/`:
 
| File | What it holds |
| --- | --- |
| `attention_report.json` | One result per case. Facts and the model's suggestion are stored under separate keys. |
| `quarantine.csv` | Every row that was set aside, with its file, line number, category and reason. |
| `summary.json` | The counts per file. Written last, so its presence means the batch finished. |
| `attempts.log` | One line per run of this batch. |
 
## When the run halts
 
If a required file is missing, or too many rows are bad, the program stops before any model call and prints one line starting with `HALTED:`. The exit code is 2. The quarantine file is still written, so you can see which rows failed and why.
 
```
HALTED: cases.csv: 4 of 8 rows (50%) were quarantined; the limit is 5%
```
 
## Check
 
```
pytest
mypy
ruff check .
```
 
Success looks like `46 passed`, `Success: no issues found in 27 source files` and `All checks passed!`.
 
## Settings
 
Settings live in `config/settings.toml`. Each setting is explained in the file.
 
To run for a different batch date without editing any file:
 
macOS or Linux: `MERIDIAN_BATCH_DATE=2025-03-13 python -m meridian_workbench`
 
Windows PowerShell: `$env:MERIDIAN_BATCH_DATE = "2025-03-13"` and then run the command above.
 
To run against another folder with the same four files, set `MERIDIAN_DATA_DIR` to that folder. Copy `data/` first, change the copy, and never change the originals to test a failure.
 
For local overrides, copy `.env.example` to `.env`. Never commit `.env`.
 
## Duplicates, batches and reruns
 
- A `case_id` must appear once. `duplicate_policy = "first_wins"` keeps the first row and quarantines the rest. `"reject_batch"` stops the whole batch instead.
- A batch ID comes from the bytes of the four input files, the batch date and the rules that change answers (AI mode, model, prompt version, duplicate policy and quarantine limit). The same inputs always give the same ID.
- If a batch already finished, a rerun reuses its result and makes no model calls. The attempt is still logged.
 
## Using a live model (optional)
 
The default mode is `recorded`: saved responses from `fixtures/` are used, so no key or internet is needed.
 
To make one bounded call per flagged note, put your own key in `.env` as `MERIDIAN_LLM_API_KEY=...` and set `MERIDIAN_AI_MODE=live`.
 
- Timeouts, rate limits and server errors are retried up to `max_attempts` times, with backoff and jitter.
- If the call still fails, the suggestion has the status `UNAVAILABLE` and the reason is printed. The facts are unchanged, and no answer is invented.
- A reply that cannot be read gets the status `INVALID_REPLY`. A model that says the note is not enough gets `ABSTAINED`.
- A successful reply is saved in `outputs/suggestion_cache.json` and reused on a safe rerun. Failures are never saved.
 
## Golden set
 
`golden/golden_set.json` holds 12 hand-written examples. Run them and score the answers by hand:
 
```
python -m meridian_workbench.golden run
python -m meridian_workbench.golden score
```
 
Fill in `golden/scoring_baseline.csv` between the two commands. `blank-sheet` creates a fresh empty sheet and overwrites the old one, so use it once.
 
## Project layout
 
```
src/meridian_workbench/   the program
    errors.py             the named intake problems (MalformedRecord, MissingSource, ...)
    parsing.py            defensive parsers for dates, units, amounts and statuses
    domain.py             the vocabulary: facts, ledgers, decisions and suggestions
    loaders.py            read each file row by row; accept or quarantine every row
    reconcile.py          required files, duplicate policy, quality gate, the books
    batch.py              batch ID, attempt ID, safe file writes, the attempt log
    retry.py              bounded retry with backoff and jitter
    llm_client.py         one model call; SDK errors become our own names
    ai_client.py          suggestion statuses, the cache, recorded and live modes
    pipeline.py           the run, from files to report
tests/                    pytest checks for every failure path and for reruns
data/                     cases.csv, notes.json, shipments.csv, inventory.csv
config/                   settings.toml
fixtures/                 recorded model responses, rows with deliberate errors
golden/                   the golden set, the hand-scoring sheet and the extra cases
docs/                     terminology.md, incident_update_template.md
outputs/                  generated batch folders (not committed)
```
