-- Run ONLY the named complete block. NEVER execute this file top to bottom.
-- A and B must be independent connections to the SAME server and meridian_retail.
-- Any unexpected write error: ROLLBACK and stop the action. Never commit partial work.
-- This is an instructor simulation of an authorised human review, not AI approval.

-- BLOCK A00 | Connection preparation
ROLLBACK;
SET autocommit=1;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
USE meridian_retail;
SELECT CONNECTION_ID() AS session_id, DATABASE() AS db_name,
       @@hostname AS server_host, @@port AS server_port;

-- BLOCK A01 | RC human accepts AFTER B01 first read
START TRANSACTION;
UPDATE support_cases SET review_status='APPROVED'
WHERE case_id='MCS-C10-RC' AND review_status='PENDING';
SELECT ROW_COUNT() AS saved_rows;

-- BLOCK A02 | ONLY if A01 saved_rows=1
INSERT INTO human_reviews
 (review_id,case_id,triggered_rule_id,reviewer_role,decision,decision_reason,
  reviewed_at,handling_minutes,extract_generated_at)
VALUES ('MHR-C10-RC','MCS-C10-RC',NULL,'CLASS10_HUMAN','APPROVED',
 'SYNTHETIC authorised classroom review; not a real customer decision',
 '2026-09-18 12:05:00',5,'2026-09-18 12:05:00');
COMMIT;

-- BLOCK A03 | RR human accepts AFTER B03 first read
START TRANSACTION;
UPDATE support_cases SET review_status='APPROVED'
WHERE case_id='MCS-C10-RR' AND review_status='PENDING';
SELECT ROW_COUNT() AS saved_rows;

-- BLOCK A04 | ONLY if A03 saved_rows=1
INSERT INTO human_reviews
 (review_id,case_id,triggered_rule_id,reviewer_role,decision,decision_reason,
  reviewed_at,handling_minutes,extract_generated_at)
VALUES ('MHR-C10-RR','MCS-C10-RR',NULL,'CLASS10_HUMAN','APPROVED',
 'SYNTHETIC authorised classroom review; not a real customer decision',
 '2026-09-18 12:05:00',5,'2026-09-18 12:05:00');
COMMIT;

-- BLOCK A05 | Lock case and inspect eligibility; leave transaction OPEN
START TRANSACTION;
SELECT case_id,review_status FROM support_cases
WHERE case_id='MCS-C10-LK' FOR UPDATE;
-- Must be PENDING. If not, ROLLBACK and stop/reset before contention.

-- BLOCK A06 | Unrelated row remains accessible BEFORE B06 starts waiting
SELECT case_id,review_status FROM support_cases
WHERE case_id='MCS-C10-OK';

-- BLOCK A07 | Run while B06 waits, after A05 returned PENDING
UPDATE support_cases SET review_status='APPROVED'
WHERE case_id='MCS-C10-LK' AND review_status='PENDING';
SELECT ROW_COUNT() AS saved_rows;

-- BLOCK A08 | ONLY if A07 saved_rows=1; releases A's lock
INSERT INTO human_reviews
 (review_id,case_id,triggered_rule_id,reviewer_role,decision,decision_reason,
  reviewed_at,handling_minutes,extract_generated_at)
VALUES ('MHR-C10-LK','MCS-C10-LK',NULL,'CLASS10_HUMAN','APPROVED',
 'SYNTHETIC authorised classroom review; not a real customer decision',
 '2026-09-18 12:05:00',5,'2026-09-18 12:05:00');
COMMIT;

-- BLOCK A09 | Stop/recovery/cleanup; never commit an unexpected attempt
ROLLBACK;
