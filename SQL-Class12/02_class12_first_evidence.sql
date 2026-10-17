-- CLASS 12 SECTION 6 | Run ENTIRE file in A. The numbers are SIMULATED representations.
USE meridian_retail;
SELECT 'AUTHORITATIVE_IN_SCENARIO' AS representation,COUNT(*) AS rows_in_representation FROM class12_legacy_orders
UNION ALL SELECT 'NIGHTLY_EXPORT',COUNT(*) FROM class12_nightly_export
UNION ALL SELECT 'LOCAL_COPY',COUNT(*) FROM class12_local_orders;
SELECT 'SOURCE' AS from_where,order_id,delivery_status,source_updated_at AS event_time
FROM class12_legacy_orders WHERE order_id IN('MR-501','MR-502','MR-000001','MR-000002','MR-000003','MR-000004')
ORDER BY order_id;
SELECT 'EXPORT' AS from_where,order_id,delivery_status,exported_at AS event_time
FROM class12_nightly_export WHERE order_id IN('MR-501','MR-502','MR-000001','MR-000002','MR-000003','MR-000004')
ORDER BY order_id;
SELECT 'LOCAL' AS from_where,order_id,delivery_status,synced_at AS event_time
FROM class12_local_orders WHERE order_id IN('MR-501','MR-502','MR-000001','MR-000002','MR-000003','MR-000004')
ORDER BY order_id;
-- Intentionally pause on these three result grids before using the joined comparison in file 03.
