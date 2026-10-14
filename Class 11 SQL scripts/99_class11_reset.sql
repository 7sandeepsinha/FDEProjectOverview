-- OPTIONAL AFTER CLASS / BEFORE A FRESH REHEARSAL ONLY. Run entire file in A.
-- CLOSE the support/service classroom connections first. Do not use while teaching.
-- Removes ONLY Class 11 identities, views and two disposable lab tables.
-- Does NOT reset Class 10 indexes/cases, Class 8 migration or Class 6 schema.
USE meridian_retail;
DROP USER IF EXISTS 'fde11_support_demo'@'localhost',
                    'fde11_service_demo'@'localhost';
DROP ROLE IF EXISTS 'fde11_support_role'@'%', 'fde11_finance_role'@'%',
                    'fde11_reporting_role'@'%', 'fde11_service_role'@'%';
DROP VIEW IF EXISTS class11_support_north_view;
DROP VIEW IF EXISTS class11_support_south_view;
DROP VIEW IF EXISTS class11_finance_view;
DROP VIEW IF EXISTS class11_reporting_view;
DROP TABLE IF EXISTS class11_audit_events;
DROP TABLE IF EXISTS class11_case_profiles;
SELECT COUNT(*) AS snapshot_rows FROM case_context_snapshot;
SELECT COUNT(*) AS class10_fixture_rows FROM class10_case_search;
SELECT table_name AS remaining_class11_object FROM information_schema.tables
WHERE table_schema=DATABASE() AND table_name LIKE 'class11\_%';
-- Expected: 25000 / 500000 and no listed Class 11 objects.
