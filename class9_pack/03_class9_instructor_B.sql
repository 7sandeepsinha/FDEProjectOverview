-- Execute ONLY the complete named block. Never run this file top to bottom.
-- A conditional success block is manual application branching, NOT automatic SQL.
-- On any unexpected write error: ROLLBACK and stop the action.
-- All statements in one transaction must stay on the same connection.

-- BLOCK B00: Prepare independent B before class
ROLLBACK;
SET autocommit=1;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
USE fde_class9_beginner_lab;
SELECT CONNECTION_ID() AS session_id;

-- BLOCK B01: Open original screen B BEFORE A08; page 17
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-DEMO';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-DEMO' ORDER BY review_id;

-- BLOCK B02: Unsafe B save AFTER A08 commits; page 18
START TRANSACTION;
UPDATE lab_cases
SET review_status='REVIEWED', current_decision='READY_FOR_HANDOFF',
    version=version+1
WHERE case_id='C9-DEMO';
INSERT INTO lab_reviews (review_id,case_id,reviewer,decision)
VALUES ('RV-UNSAFE-B','C9-DEMO','B','READY_FOR_HANDOFF');
COMMIT;

-- BLOCK B03: Open version 1 screen B BEFORE A11; page 21
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-DEMO';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-DEMO' ORDER BY review_id;

-- BLOCK B04: Old version save AFTER A12 commits; page 22
START TRANSACTION;
UPDATE lab_cases
SET review_status='REVIEWED', current_decision='READY_FOR_HANDOFF',
    version=version+1
WHERE case_id='C9-DEMO' AND version=1
  AND review_status='PENDING';
SELECT ROW_COUNT() AS saved_rows;

-- BLOCK B05: Expected zero-row branch; NO event insert; page 22
ROLLBACK;
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-DEMO';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-DEMO' ORDER BY review_id;
