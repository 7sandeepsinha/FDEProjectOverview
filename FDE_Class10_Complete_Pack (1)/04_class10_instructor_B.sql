-- Run ONLY the named complete block. NEVER execute this file top to bottom.
-- A and B must be independent connections to the SAME server and meridian_retail.
-- Any unexpected write error: ROLLBACK and stop the action. Never commit partial work.
-- This is an instructor simulation of an authorised human review, not AI approval.

-- BLOCK B00 | Prepare independent B
ROLLBACK;
SET autocommit=1;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
USE meridian_retail;
SELECT CONNECTION_ID() AS session_id, DATABASE() AS db_name,
       @@hostname AS server_host, @@port AS server_port;

-- BLOCK B01 | RC first read, BEFORE A01/A02
ROLLBACK;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
SELECT case_id,review_status FROM support_cases WHERE case_id='MCS-C10-RC';

-- BLOCK B02 | RC second read, AFTER A02 committed
SELECT case_id,review_status FROM support_cases WHERE case_id='MCS-C10-RC';
ROLLBACK;

-- BLOCK B03 | RR first read, BEFORE A03/A04
ROLLBACK;
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT case_id,review_status FROM support_cases WHERE case_id='MCS-C10-RR';
-- This FIRST ordinary read establishes the snapshot in our demo.

-- BLOCK B04 | RR second ordinary read, AFTER A04 committed
SELECT case_id,review_status FROM support_cases WHERE case_id='MCS-C10-RR';
-- Still PENDING. Leave B transaction open until B05.

-- BLOCK B05 | End old snapshot; a new read observes accepted state
ROLLBACK;
SELECT case_id,review_status FROM support_cases WHERE case_id='MCS-C10-RR';
-- APPROVED (autocommit=1, new statement/transaction).

-- BLOCK B05U | Run AFTER A05; an unrelated primary-key row can be locked
START TRANSACTION;
SELECT case_id,review_status FROM support_cases
WHERE case_id='MCS-C10-OK' FOR UPDATE;
ROLLBACK;
-- Returns immediately: unrelated row, not a whole-database freeze.

-- BLOCK B06 | Start AFTER A05 acquired LK row; statement WILL WAIT
ROLLBACK;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
SELECT case_id,review_status FROM support_cases
WHERE case_id='MCS-C10-LK' FOR UPDATE;
-- Run A07/A08 in A while this query waits. Do not cancel a normal brief wait.
-- After A commits, this returns APPROVED and B holds its own lock.

-- BLOCK B07 | APPROVED is ineligible for another pending-case acceptance
-- Do NOT UPDATE or INSERT an accepted event. Close rejected attempt.
ROLLBACK;
SELECT review_id,decision FROM human_reviews WHERE case_id='MCS-C10-LK';
-- One event, MHR-C10-LK. Acquiring the lock did not authorise another review.

-- BLOCK B08 | End-of-class cleanup / error path (after waiting query returns)
ROLLBACK;
