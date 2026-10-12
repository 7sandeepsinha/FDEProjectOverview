-- Execute ONLY the complete named block. Never run this file top to bottom.
-- A conditional success block is manual application branching, NOT automatic SQL.
-- On any unexpected write error: ROLLBACK and stop the action.
-- All statements in one transaction must stay on the same connection.

-- BLOCK A00: Prepare A before class
ROLLBACK;
SET autocommit=1;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
USE fde_class9_beginner_lab;
SELECT CONNECTION_ID() AS session_id;

-- BLOCK A01: Baseline; page 4
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-DEMO';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-DEMO' ORDER BY review_id;

-- BLOCK A02: One write committed alone; page 6
UPDATE lab_cases
SET review_status='REVIEWED', current_decision='NEEDS_INFO',
    version=version+1
WHERE case_id='C9-DEMO';
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-DEMO';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-DEMO' ORDER BY review_id;

-- BLOCK A03: Rollback after completed autocommit; page 6
ROLLBACK;
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-DEMO';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-DEMO' ORDER BY review_id;

-- BLOCK A04: Begin failure demonstration; page 11
START TRANSACTION;
UPDATE lab_cases
SET review_status='REVIEWED', current_decision='NEEDS_INFO',
    version=version+1
WHERE case_id='C9-DEMO';

-- BLOCK A05: EXPECTED foreign-key error; page 11. Run by itself
INSERT INTO lab_reviews (review_id,case_id,reviewer,decision)
VALUES ('RV-ERROR','C9-MISSING','A','NEEDS_INFO');

-- BLOCK A06: Explicitly cancel failed business action; page 11
ROLLBACK;
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-DEMO';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-DEMO' ORDER BY review_id;

-- BLOCK A07: Open original screen A; page 17
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-DEMO';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-DEMO' ORDER BY review_id;

-- BLOCK A08: Unsafe save A; page 17
START TRANSACTION;
UPDATE lab_cases
SET review_status='REVIEWED', current_decision='NEEDS_INFO',
    version=version+1
WHERE case_id='C9-DEMO';
INSERT INTO lab_reviews (review_id,case_id,reviewer,decision)
VALUES ('RV-UNSAFE-A','C9-DEMO','A','NEEDS_INFO');
COMMIT;

-- BLOCK A09: Inspect after B02; page 18
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-DEMO';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-DEMO' ORDER BY review_id;

-- BLOCK A10: Open version 1 screen A; page 21
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-DEMO';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-DEMO' ORDER BY review_id;

-- BLOCK A11: Guarded update A; STOP inspect saved_rows; page 21
START TRANSACTION;
UPDATE lab_cases
SET review_status='REVIEWED', current_decision='NEEDS_INFO',
    version=version+1
WHERE case_id='C9-DEMO' AND version=1
  AND review_status='PENDING';
SELECT ROW_COUNT() AS saved_rows;

-- BLOCK A12: ONLY if A11 returned 1; page 21
INSERT INTO lab_reviews (review_id,case_id,reviewer,decision)
VALUES ('RV-SAFE-A','C9-DEMO','A','NEEDS_INFO');
COMMIT;
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-DEMO';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-DEMO' ORDER BY review_id;

-- BLOCK A13: If A11 returned 0 OR any write failed; do not run A12
ROLLBACK;
