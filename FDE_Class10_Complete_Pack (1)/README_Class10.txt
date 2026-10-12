FDE CLASS 10 DELIVERY PACK
27 pages. 135 minutes including in-class execution and a seven-minute break.

START WITH THE DOCX
Open FDE_Class10_Beginner_First_Instructor_Script.docx and follow it in order.
The lesson begins with the Class 9 recap. Database checks, teaching data and
connection steps appear at the point where the class needs them.
Every live demo includes SQL, its connection, expected observations and teaching.
This README is optional file information; it is not part of the delivery path.

FILES
00_class10_preflight.sql: existing Meridian checks, used within the opening.
01_class10_setup.sql: one-time teaching additions, used after the opening checks.
02_class10_reset_concurrency.sql: reset teaching cases only if replaying demos.
03_class10_instructor_A.sql and 04_class10_instructor_B.sql: optional SQL copies.
05_class10_learner_performance.sql: optional copy of performance SQL.
06_class10_reset_performance.sql: optional selected-index reset for repeat practice.
The live SQL is printed directly in the document; no block-name lookup is needed.
The A/B/performance files are collections of selected blocks, not whole-file runs.

EXISTING SETUP
Do not rerun Class 6 DROP DATABASE or repeat the Class 8 migration.
If the Class 10 additions already exist, follow the document's skip/reset cue.
The operational view has 25004 cases after setup; the stored snapshot stays 25000.

VALIDATION
The SQL files and teaching workload are unchanged in this rearrangement.
The document separates INSERT success checks from COMMIT in the live demos.
Logical result checks were performed independently; there was no MySQL runtime
available for live InnoDB wait or optimiser testing during authoring.
The class uses actual output and timings from the delivery server.

TECHNICAL REFERENCES
MySQL 8.0 Reference Manual, verified during authoring:
https://dev.mysql.com/doc/refman/8.0/en/innodb-consistent-read.html
https://dev.mysql.com/doc/refman/8.0/en/innodb-locking-reads.html
https://dev.mysql.com/doc/refman/8.0/en/innodb-deadlocks-handling.html
https://dev.mysql.com/doc/refman/8.0/en/explain.html
https://dev.mysql.com/doc/refman/8.0/en/explain-output.html
https://dev.mysql.com/doc/refman/8.0/en/multiple-column-indexes.html
https://dev.mysql.com/doc/refman/8.0/en/mysql-indexes.html

FDE CONTEXT
Supplied FDE Handbook Chapter 10: customer-system integration and evidence
ownership. The workload and SQL are teaching adaptations, not handbook extracts.
Class 11 bridge: identity, permissions, PII and auditability.
Recovery choices, uncertain outcomes and external boundaries are introduced
conceptually. Implemented retries/idempotency/outbox and lock internals remain
for backend reliability, messaging and advanced database treatment.

ADDITIONAL PRIMARY REFERENCES FOR THE CLASS 9 HANDOFF
MySQL isolation behaviours
https://dev.mysql.com/doc/refman/8.0/en/innodb-transaction-isolation-levels.html
MySQL error rollback boundaries
https://dev.mysql.com/doc/refman/8.0/en/innodb-error-handling.html
MySQL deadlock prevention and recovery
https://dev.mysql.com/doc/refman/8.0/en/innodb-deadlocks-handling.html
