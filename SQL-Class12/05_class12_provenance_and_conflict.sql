-- CLASS 12 SECTIONS 7-9 | Run ENTIRE file in A after interpreting freshness.
USE meridian_retail;
SELECT s.order_id,s.delivery_status AS source_status,
 DATE_FORMAT(s.source_updated_at,'%Y-%m-%d %H:%i') AS source_updated_at,
 e.delivery_status AS export_status,
 DATE_FORMAT(e.exported_at,'%Y-%m-%d %H:%i') AS exported_at,
 l.delivery_status AS local_status,
 DATE_FORMAT(l.synced_at,'%Y-%m-%d %H:%i') AS synced_at
FROM class12_legacy_orders s
LEFT JOIN class12_nightly_export e ON e.order_id=s.order_id
LEFT JOIN class12_local_orders l ON l.order_id=s.order_id
WHERE s.order_id IN('MR-000002','MR-502') ORDER BY s.order_id;
SELECT run_id,pipeline_name,DATE_FORMAT(started_at,'%Y-%m-%d %H:%i') AS started_at,
 DATE_FORMAT(finished_at,'%Y-%m-%d %H:%i') AS finished_at,outcome,rows_reported,note
FROM class12_sync_runs ORDER BY started_at;
SELECT s.order_id AS source_order,e.order_id AS export_order,l.order_id AS local_order
FROM class12_legacy_orders s
LEFT JOIN class12_nightly_export e ON e.order_id=s.order_id
LEFT JOIN class12_local_orders l ON l.order_id=s.order_id
WHERE s.order_id IN('MR-000001','MR-000004') ORDER BY s.order_id;
-- Do not auto-overwrite discrepancy. Escalate for authoritative owner and ingestion review.
