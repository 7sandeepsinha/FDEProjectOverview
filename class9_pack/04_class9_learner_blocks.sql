-- Execute ONLY the complete named block. Never run this file top to bottom.
-- A conditional success block is manual application branching, NOT automatic SQL.
-- On any unexpected write error: ROLLBACK and stop the action.
-- All statements in one transaction must stay on the same connection.

-- BLOCK L00: Prepare and inspect; page 4
ROLLBACK;
SET autocommit=1;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
USE fde_class9_beginner_lab;
SELECT CONNECTION_ID() AS session_id;
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-PRACTICE';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-PRACTICE' ORDER BY review_id;

-- BLOCK L01: Stage both writes; STOP before finishing; page 8
START TRANSACTION;
UPDATE lab_cases
SET review_status='REVIEWED', current_decision='NEEDS_INFO',
    version=version+1
WHERE case_id='C9-PRACTICE';
INSERT INTO lab_reviews (review_id,case_id,reviewer,decision)
VALUES ('RV-PRACTICE-TX','C9-PRACTICE','ME','NEEDS_INFO');
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-PRACTICE';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-PRACTICE' ORDER BY review_id;

-- BLOCK L02: Cancel L01 and inspect; page 9
ROLLBACK;
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-PRACTICE';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-PRACTICE' ORDER BY review_id;

-- BLOCK L03: Repeat and commit; page 10
START TRANSACTION;
UPDATE lab_cases
SET review_status='REVIEWED', current_decision='NEEDS_INFO',
    version=version+1
WHERE case_id='C9-PRACTICE';
INSERT INTO lab_reviews (review_id,case_id,reviewer,decision)
VALUES ('RV-PRACTICE-TX','C9-PRACTICE','ME','NEEDS_INFO');
COMMIT;
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-PRACTICE';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-PRACTICE' ORDER BY review_id;

-- BLOCK L04: Rollback after commit does not undo it; page 10
ROLLBACK;
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-PRACTICE';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-PRACTICE' ORDER BY review_id;

-- BLOCK L05: Reset ONLY learner practice; page 23
ROLLBACK;
START TRANSACTION;
DELETE FROM lab_reviews WHERE case_id='C9-PRACTICE';
UPDATE lab_cases SET review_status='PENDING', current_decision=NULL, version=1
WHERE case_id='C9-PRACTICE';
COMMIT;
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-PRACTICE';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-PRACTICE' ORDER BY review_id;

-- BLOCK L06: First guarded attempt; STOP inspect saved_rows; page 23
START TRANSACTION;
UPDATE lab_cases
SET review_status='REVIEWED', current_decision='NEEDS_INFO',
    version=version+1
WHERE case_id='C9-PRACTICE' AND version=1
  AND review_status='PENDING';
SELECT ROW_COUNT() AS saved_rows;

-- BLOCK L07: ONLY if L06 returned 1; page 23
INSERT INTO lab_reviews (review_id,case_id,reviewer,decision)
VALUES ('RV-PRACTICE-SAFE','C9-PRACTICE','ME','NEEDS_INFO');
COMMIT;
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-PRACTICE';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-PRACTICE' ORDER BY review_id;

-- BLOCK L08: Repeat with OLD version 1; STOP inspect saved_rows; page 24
START TRANSACTION;
UPDATE lab_cases
SET review_status='REVIEWED', current_decision='READY_FOR_HANDOFF',
    version=version+1
WHERE case_id='C9-PRACTICE' AND version=1
  AND review_status='PENDING';
SELECT ROW_COUNT() AS saved_rows;

-- BLOCK L09: Expected zero-row branch; page 24
ROLLBACK;
SELECT case_id,review_status,current_decision,version
FROM lab_cases WHERE case_id='C9-PRACTICE';
SELECT review_id,reviewer,decision FROM lab_reviews
WHERE case_id='C9-PRACTICE' ORDER BY review_id;

-- BLOCK L10: Unexpected result/error recovery; never commit blindly
ROLLBACK;
