# Terminology agreement
 
Agreed between the Workbench engineer and the Meridian ops lead. If a word in the code or a report
does not match this page, the page wins and the code gets fixed.
 
| Term | Meaning | Where it lives |
| --- | --- | --- |
| Case | One customer problem about one order. One row in `cases.csv`, identified by `case_id`. | `SupportCase` |
| Evidence | Words or records from a source that back a statement. A note's text is evidence. A model's opinion is not. | `SourceEvidence` |
| Source-of-truth fact | A value read from a source file and never changed by the program: `case_id`, `order_id`, `order_status`, `promised_date`, shipment and inventory values. | `SupportCase`, `ShipmentInfo`, `InventoryInfo` |
| Decision | A result the Python rules compute from facts: needs attention or not, the reason, days overdue. | `AttentionDecision` |
| Suggestion | What a model proposes after reading a note. It is always labelled, always keeps its `case_id` and `source_note_id`, and is never written back into a fact. | `CaseSuggestion` |
| Rejected record | A source row the program refused to load, with the reason. | `RejectedRecord` |
 
## Rules we agreed
 
1. Only a source file can change a fact. A suggestion never does.
2. A suggestion that quotes evidence must quote it exactly from the note.
3. When a note does not say what the problem is, the right answer is to abstain and ask for review.
4. "Needs attention" is decided by the rules, never by the model.
