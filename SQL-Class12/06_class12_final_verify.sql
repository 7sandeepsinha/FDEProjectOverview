-- CLASS 12 SECTION 10 | Run ENTIRE file in A. Do not drop lab during teaching.
USE meridian_retail;
SELECT 'class12_legacy_orders' AS object_name,COUNT(*) AS rows_found FROM class12_legacy_orders
UNION ALL SELECT 'class12_nightly_export',COUNT(*) FROM class12_nightly_export
UNION ALL SELECT 'class12_local_orders',COUNT(*) FROM class12_local_orders
UNION ALL SELECT 'class12_sync_runs',COUNT(*) FROM class12_sync_runs;
SELECT (SELECT COUNT(*) FROM case_context_snapshot) AS prior_snapshot_rows,
       (SELECT COUNT(*) FROM class10_case_search) AS prior_performance_rows,
       (SELECT COUNT(*) FROM support_cases WHERE case_id IN ('MCS-C10-RC','MCS-C10-RR','MCS-C10-LK','MCS-C10-OK')) AS prior_teaching_cases;
-- Expected Class12 counts 24/23/23/4; existing snapshot 25000, fixture 500000, teaching cases 4.
