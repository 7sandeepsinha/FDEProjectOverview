-- CLASS 12 | READ ONLY | Run the ENTIRE file in the existing instructor connection A.
-- This is the SAME meridian_retail database from Classes 6-11. No new database.
-- Stop if the source classroom state differs; never rerun the Class 6 destructive reset.
USE meridian_retail;
SELECT DATABASE() AS database_name, VERSION() AS mysql_version, CONNECTION_ID() AS session_id;
SELECT COUNT(*) AS original_case_snapshot_rows FROM case_context_snapshot;
SELECT COUNT(*) AS class10_performance_observations FROM class10_case_search;
SELECT COUNT(*) AS class10_teaching_cases FROM support_cases
WHERE case_id IN ('MCS-C10-RC','MCS-C10-RR','MCS-C10-LK','MCS-C10-OK');
SELECT COUNT(*) AS available_anchor_and_generated_orders FROM orders
WHERE order_id IN ('MR-501','MR-502','MR-000001','MR-000002','MR-000003','MR-000004','MR-000005','MR-000006',
'MR-000007','MR-000008','MR-000009','MR-000010','MR-000011','MR-000012','MR-000013','MR-000014',
'MR-000015','MR-000016','MR-000017','MR-000018','MR-000019','MR-000020','MR-000021','MR-000022');
SELECT table_name AS preexisting_class12_object FROM information_schema.tables
WHERE table_schema=DATABASE() AND table_name LIKE 'class12\_%';
-- Expected 25000 / 500000 / 4 / 24 and no class12_ objects.
-- Existing class11_ tables may still be present; they are not changed by Class 12.
