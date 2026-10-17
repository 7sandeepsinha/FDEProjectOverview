-- OPTIONAL BETWEEN REHEARSALS ONLY | Run ENTIRE file in A, NEVER during delivery.
-- Removes ONLY the Class 12 simulated integration tables inside meridian_retail.
-- Does not touch Class 6-11 tables, indexes, views, accounts or roles.
USE meridian_retail;
DROP TABLE IF EXISTS class12_sync_runs;
DROP TABLE IF EXISTS class12_local_orders;
DROP TABLE IF EXISTS class12_nightly_export;
DROP TABLE IF EXISTS class12_legacy_orders;
SELECT table_name AS remaining_class12_table FROM information_schema.tables
WHERE table_schema=DATABASE() AND table_name LIKE 'class12\_%';
SELECT COUNT(*) AS original_case_snapshot_rows FROM case_context_snapshot;
SELECT COUNT(*) AS class10_performance_observations FROM class10_case_search;
-- Expected no class12_ tables, and prior counts 25000 / 500000.
