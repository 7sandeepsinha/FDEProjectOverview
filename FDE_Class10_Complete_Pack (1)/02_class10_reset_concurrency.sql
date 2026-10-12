-- Rehearsal/reset ONLY. FIRST finish/rollback A and B, including any waiter.
-- No route rows are created by this pack. Do not add routes to these review IDs.
-- Do not run while B is waiting: end holder A, wait for B to return, rollback B.
USE meridian_retail;
START TRANSACTION;
DELETE FROM human_reviews WHERE review_id IN
 ('MHR-C10-RC','MHR-C10-RR','MHR-C10-LK');
UPDATE support_cases SET review_status='PENDING'
WHERE case_id IN ('MCS-C10-RC','MCS-C10-RR','MCS-C10-LK','MCS-C10-OK');
COMMIT;
SELECT case_id,review_status FROM support_cases
WHERE case_id IN ('MCS-C10-RC','MCS-C10-RR','MCS-C10-LK','MCS-C10-OK')
ORDER BY case_id;
-- Expected four PENDING cases. This is a NEW classroom change, not historical undo.
