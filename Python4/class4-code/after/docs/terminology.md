# Terminology agreement
 
Agreed between the Workbench engineer and the Meridian ops lead. If a word in the code or a report
does not match this page, the page wins and the code gets fixed.
 
| Term | Meaning | Where it lives |
| --- | --- | --- |
| Case | One customer problem about one order. One row in `cases.csv`, identified by `case_id`. | `SupportCase` |
| Evidence | Words or records from a source that back a statement. A note's text is evidence. A model's opinion is not. | `SourceEvidence` |
| Source-of-truth fact | A value read from a source file and never changed by the program: `case_id`, `order_id`, `order_status`, `promised_date`, shipment and inventory values. | `SupportCase`, `ShipmentInfo`, `InventoryInfo` |
| Ledger | The books for one source file: rows read, rows accepted, rows quarantined. They must balance. | `Ledger` |
| Quarantine | A row or note set aside with a category and a reason. Nothing is deleted. | `RejectedRecord`, `quarantine.csv` |
| Decision | A result the Python rules compute from facts: needs attention or not, the reason, days overdue. | `AttentionDecision` |
| Suggestion | What a model proposes after reading a note. It has a status, always keeps its `case_id` and `source_note_id`, and is never written back into a fact. | `CaseSuggestion` |
| Batch | The work for one set of input files, one date and one set of rules. It has a stable ID. | `batch_id_for` |
| Attempt | One run of a batch. Each attempt has its own ID and a line in `attempts.log`. | `new_attempt_id` |
 
## Rules we agreed
 
1. Only a source file can change a fact. A suggestion never does.
2. A suggestion that quotes evidence must quote it exactly from the note.
3. When a note does not say what the problem is, the right answer is to abstain and ask for review.
4. "Needs attention" is decided by the rules, never by the model.
5. Every source row is either accepted or quarantined with a reason. There is no third outcome.
6. A model that is unavailable gives the status UNAVAILABLE. The program never fills the gap with an invented answer.
