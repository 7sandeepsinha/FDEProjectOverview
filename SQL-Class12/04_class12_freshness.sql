-- CLASS 12 SECTION 7 | Run ENTIRE file in A. A fixed scenario clock makes it reproducible.
USE meridian_retail;
SELECT '2026-09-20 10:00:00' AS scenario_clock,
 DATE_FORMAT(MAX(finished_at),'%Y-%m-%d %H:%i:%s') AS last_completed_local_sync,
 TIMESTAMPDIFF(MINUTE,MAX(finished_at),'2026-09-20 10:00:00') AS sync_age_minutes,
 5 AS status_lookup_max_age_minutes,
 CASE WHEN TIMESTAMPDIFF(MINUTE,MAX(finished_at),'2026-09-20 10:00:00') <= 5
 THEN 'WITHIN_TARGET' ELSE 'TOO_OLD_FOR_FIVE_MINUTE_USE' END AS freshness_check
FROM class12_sync_runs WHERE pipeline_name='LOCAL_COPY' AND outcome='SUCCESS';
SELECT order_id,delivery_status,
 DATE_FORMAT(synced_at,'%Y-%m-%d %H:%i') AS synced_at,
 TIMESTAMPDIFF(MINUTE,synced_at,'2026-09-20 10:00:00') AS copy_age_minutes
FROM class12_local_orders WHERE order_id IN('MR-501','MR-502','MR-000002') ORDER BY order_id;
SELECT 'NEXT_MORNING_REPORT' AS use_case,
 DATE_FORMAT(MAX(exported_at),'%Y-%m-%d %H:%i') AS file_created_at,
 TIMESTAMPDIFF(HOUR,MAX(exported_at),'2026-09-20 10:00:00') AS file_age_hours,
 CASE WHEN TIMESTAMPDIFF(HOUR,MAX(exported_at),'2026-09-20 10:00:00') <= 24
 THEN 'WITHIN_24H_AGE_ONLY' ELSE 'OLDER_THAN_24H' END AS age_check
FROM class12_nightly_export;
-- Expected 18 minutes for local last-success age; 11 hours for export age.
-- A valid timestamp DOES NOT prove the export includes all orders or that values agree.
