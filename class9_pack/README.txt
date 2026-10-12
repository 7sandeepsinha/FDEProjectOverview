FDE CLASS 9 — BEGINNER-FIRST SQL PACK
Companion: FDE_Class9_Beginner_First_Instructor_Script.pdf (28 pages).
Duration: 135 minutes, including a seven-minute break.

THIS PACK REPLACES THE PREVIOUS CLASS 9 DELIVERY PACK FOR THIS LESSON.
It uses fde_class9_beginner_lab, versions starting at 1, and two synthetic cases.
It does not change meridian_retail, rerun Class 8, or change the old fde_class9_lab.
Do not mix old Class 9 block numbers/files with this script.

REQUIREMENTS
MySQL 8.0.18+ with InnoDB and permission to create a disposable lab database.
Instructor: two independent connections A and B to the same server/database.
Learner: one connection to their own prepared disposable instance/database.
Do not let all learners write C9-PRACTICE on one shared database.
If the delivery platform has only one independent connection, use the supplied
storyboard and labelled rehearsal screenshots for A/B; do not claim two tabs
on one session are independent connections.

FILES
00_class9_lab_setup.sql — Run once before class on each disposable instance.
01_class9_reset_demo.sql — Run in A between demos, after rollback in A and B.
02_class9_instructor_A.sql — Select only the named A block.
03_class9_instructor_B.sql — Select only the named B block.
04_class9_learner_blocks.sql — Select only the named learner block.

EXECUTION RULES
Never run the A, B or learner file from top to bottom.
Select the complete named block, including its final semicolon.
Use the same connection for every statement of a transaction.
Check saved_rows immediately after the guarded UPDATE; do not insert another
statement between UPDATE and SELECT ROW_COUNT().
1 row: only then run the corresponding event insert/COMMIT success block.
0 rows: no accepted event; ROLLBACK and diagnose/refresh/review current state.
Any unexpected write error: ROLLBACK and stop this business action.
The SQL editor does not automatically branch based on the row count.

PREPARATION
Run setup, then A00 in A and B00 in B. Confirm different session_id values.
Learners run L00 at page 4. No isolation-level lecture is required: these are
consistent preparation settings. START TRANSACTION overrides autocommit for
that explicit group. Setup is CREATE-only: if the database already exists,
stop and inspect schema rather than continuing after an error.

DEMO ORDER (reset means ROLLBACK in both A/B, then reset_demo in A)
Page 6 incomplete save: reset; A02; A03.
  Expected: REVIEWED, NEEDS_INFO, v2; zero events, including after ROLLBACK.
Page 11 failure: reset; A04; A05 ALONE (expected FK error); A06.
  Expected after rollback: PENDING, NULL, v1, zero events.
Pages 17–18 unsafe screen: reset; A07; B01; A08; B02; A09.
  Expected: READY_FOR_HANDOFF, v3; two events.
Pages 21–22 safe screen: reset; A10; B03; A11 -> 1; A12; B04 -> 0; B05.
  Expected: NEEDS_INFO, v2; only RV-SAFE-A.
If A11 is not 1, run A13 instead of A12 and stop/recover.
Page 25 locking example is SHOW ONLY; no live lock demonstration is included.

LEARNER ORDER
Page 4: L00 -> PENDING/NULL/v1, no events.
Page 8: L01 -> own uncommitted REVIEWED/NEEDS_INFO/v2 and one event.
Page 9: L02 -> rollback restores PENDING/NULL/v1 and no events.
Page 10: L03 -> commit yields REVIEWED/NEEDS_INFO/v2 and one event.
          L04 -> subsequent rollback leaves that committed state unchanged.
Page 23: L05 -> reset practice; L06 -> 1; only then L07 -> commit.
Page 24: L08 -> 0; L09 -> rollback; v2 and one event remain.
L10 is rollback recovery for unexpected results/errors. Do not commit blindly.

RECOVERY
If setup reports database exists, inspect SHOW CREATE TABLE for lab_cases and
lab_reviews. If schema matches this disposable lab, reset the instructor case
and use L05 to reset practice. If it does not match, prepare a fresh disposable
instance before learner practice. Do not run an improvised DROP.
Reset does not undo a historical commit: it performs new classroom changes.
If any session is waiting on a lock, finish the holder first, let the waiting
query return, then roll back the waiter before reset. Limit live recovery to
60 seconds; switch to a labelled rehearsal screenshot if needed.

VALIDATION / REHEARSAL
Block references, inline SQL and expected state transitions were checked.
Core rollback, commit, failed-write rollback, overwrite and version-guard
outcomes were exercised in a local SQLite transaction model after translating
MySQL-specific setup/ROW_COUNT syntax. This is a logic check, not a MySQL
compatibility or InnoDB locking test. No MySQL server was available in the
artifact-building environment. Rehearse all orders above on the actual
MySQL server before delivery and retain screenshots. Do not improvise new
isolation/deadlock experiments during this beginner class.

TECHNICAL REFERENCES (MySQL 8.0 Reference Manual)
https://dev.mysql.com/doc/refman/8.0/en/innodb-autocommit-commit-rollback.html
https://dev.mysql.com/doc/refman/8.0/en/innodb-error-handling.html
https://dev.mysql.com/doc/refman/8.0/en/innodb-locking-reads.html
https://dev.mysql.com/doc/refman/8.0/en/implicit-commit.html

DEFERRED CONTENT
The final page of the instructor script records isolation/read anomalies,
locking practice, deadlocks, bounded retries, idempotency, external effects
and production implementation boundaries for the next script. No live join,
subquery or prior-class migration is required in this pack.
