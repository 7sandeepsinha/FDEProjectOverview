-- READ ONLY. Run the entire file before setup on the classroom copy.
-- Required: Oracle MySQL 8.0.18+ / InnoDB, evolved Class 8 Meridian schema.
-- No earlier reset or migration is run by this pack.
USE meridian_retail;
SELECT VERSION() AS server_version, DATABASE() AS database_name,
       CONNECTION_ID() AS session_id;
SELECT table_name, engine FROM information_schema.tables
WHERE table_schema=DATABASE() AND table_name IN
 ('orders','support_cases','issue_records','human_reviews','customers',
  'products','case_routes','case_context_snapshot');
SHOW COLUMNS FROM support_cases;
SHOW COLUMNS FROM human_reviews;
SHOW COLUMNS FROM issue_records;
SELECT COUNT(*) AS snapshot_rows FROM case_context_snapshot;
SELECT COUNT(*) AS view_rows FROM vw_case_context;
SELECT case_id,review_status FROM support_cases
WHERE case_id IN ('MCS-501','MCS-502');
SELECT COUNT(*) AS reserved_case_collisions FROM support_cases
WHERE case_id IN ('MCS-C10-RC','MCS-C10-RR','MCS-C10-LK','MCS-C10-OK');
SELECT table_name FROM information_schema.tables
WHERE table_schema=DATABASE() AND table_name='class10_case_search';
-- Before FIRST setup: snapshot_rows=25000, view_rows=25000,
-- collisions=0, final result empty. Stop if prerequisites do not match.
-- After setup: view_rows=25004, collisions=4; this means inspect/reset,
-- not rerun setup. Snapshot remains 25000.
