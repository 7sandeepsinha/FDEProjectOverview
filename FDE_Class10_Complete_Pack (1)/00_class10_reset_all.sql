-- CLASS 10 FULL RESET -- run this entire file in connection A.
-- Returns Meridian to BEFORE the Class 10 setup, not to an empty database.
-- Removes only the named Class 10 teaching cases, review events and fixture.
-- It also removes any indexes on that disposable performance fixture.
-- Can be run again if some or all of these teaching additions are absent.
--
-- FIRST: run ROLLBACK; in connection B if it is open.
-- If B is waiting, run ROLLBACK; in A, let B return, then ROLLBACK; in B.
-- Then run this whole file in A. Do not run it while another demo is active.
-- If any statement errors, stop and share the error before continuing class.

USE meridian_retail;
ROLLBACK;
SET autocommit=1;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Clears a temporary guard left by an interrupted setup in this connection.
DROP TEMPORARY TABLE IF EXISTS class10_setup_guard;

START TRANSACTION;
DELETE FROM human_reviews
WHERE review_id IN ('MHR-C10-RC','MHR-C10-RR','MHR-C10-LK')
  AND case_id IN ('MCS-C10-RC','MCS-C10-RR','MCS-C10-LK');
DELETE FROM support_cases
WHERE case_id IN ('MCS-C10-RC','MCS-C10-RR','MCS-C10-LK','MCS-C10-OK');
COMMIT;

-- The fixture is synthetic Class 10 practice data. Core tables are not dropped.
DROP TABLE IF EXISTS class10_case_search;

-- RESET CHECK: all three remaining_* values should be 0.
SELECT
  (SELECT COUNT(*) FROM support_cases
   WHERE case_id IN ('MCS-C10-RC','MCS-C10-RR','MCS-C10-LK','MCS-C10-OK'))
    AS remaining_class10_cases,
  (SELECT COUNT(*) FROM human_reviews
   WHERE review_id IN ('MHR-C10-RC','MHR-C10-RR','MHR-C10-LK'))
    AS remaining_class10_reviews,
  (SELECT COUNT(*) FROM information_schema.tables
   WHERE table_schema='meridian_retail' AND table_name='class10_case_search')
    AS remaining_class10_fixture;

-- In the supplied original post-Class-8 database, both should be 25000.
SELECT COUNT(*) AS snapshot_rows FROM case_context_snapshot;
SELECT COUNT(*) AS view_rows FROM vw_case_context;

-- These original Meridian anchor cases should still be present.
SELECT case_id,review_status FROM support_cases
WHERE case_id IN ('MCS-501','MCS-502') ORDER BY case_id;

-- NEXT: follow the revised instructor script from its opening.
-- When instructed, run 00_class10_preflight.sql, then 01_class10_setup.sql.
