-- Section 11 | Run entire file in A to verify intended end state.
USE meridian_retail;
SELECT COUNT(*) AS class11_profiles FROM class11_case_profiles;
SELECT (SELECT COUNT(*) FROM class11_support_north_view) AS north_visible,
       (SELECT COUNT(*) FROM class11_support_south_view) AS south_visible;
SELECT COUNT(*) AS class11_synthetic_audit_events FROM class11_audit_events;
SHOW GRANTS FOR 'fde11_support_role'@'%';
SHOW GRANTS FOR 'fde11_service_role'@'%';
SELECT COUNT(*) AS original_snapshot_rows FROM case_context_snapshot;
SELECT COUNT(*) AS original_class10_fixture_rows FROM class10_case_search;
-- Expected: 24 profiles, north=12, south=12, 12 synthetic events,
-- snapshot=25000, Class 10 fixture=500000. Verify grants show NO raw-table access.
