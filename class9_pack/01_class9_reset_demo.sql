-- Before running: ROLLBACK in A and B. Release any waiting query first.
-- Reset ONLY the instructor case. Learner practice is preserved.
USE fde_class9_beginner_lab;
START TRANSACTION;
DELETE FROM lab_reviews WHERE case_id='C9-DEMO';
UPDATE lab_cases SET review_status='PENDING', current_decision=NULL, version=1
WHERE case_id='C9-DEMO';
COMMIT;
SELECT * FROM lab_cases WHERE case_id='C9-DEMO';
SELECT COUNT(*) AS accepted_reviews FROM lab_reviews WHERE case_id='C9-DEMO';
