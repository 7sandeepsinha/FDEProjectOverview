-- CLASS 11: READ-ONLY PREFLIGHT. Run entire file in instructor connection A.
-- Expected environment: post-Class-10 meridian_retail on a disposable classroom MySQL 8 server.
-- If a prerequisite does not match, STOP; do not rerun the Class 6 destructive reset.
USE meridian_retail;
SELECT VERSION() AS mysql_version, DATABASE() AS active_database,
       CURRENT_USER() AS authenticated_account, CURRENT_ROLE() AS active_roles;
SELECT COUNT(*) AS snapshot_rows FROM case_context_snapshot;
SELECT COUNT(*) AS live_case_rows FROM vw_case_context;
SELECT COUNT(*) AS class10_observations FROM class10_case_search;
SELECT COUNT(*) AS class10_reserved_cases FROM support_cases
WHERE case_id IN ('MCS-C10-RC','MCS-C10-RR','MCS-C10-LK','MCS-C10-OK');
SELECT table_name AS preexisting_class11_table
FROM information_schema.tables
WHERE table_schema = DATABASE() AND table_name LIKE 'class11\_%';
-- Expected: snapshot=25000, live view=25004, Class 10 fixture=500000,
-- 4 reserved Class 10 cases, no Class 11 tables listed.
-- The instructor account also needs CREATE USER/ROLE and authority to GRANT/REVOKE
-- on this disposable lab. Prior DDL access does not automatically imply those rights.
SHOW GRANTS;
