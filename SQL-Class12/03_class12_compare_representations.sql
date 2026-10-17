-- CLASS 12 SECTION 6 | Run ENTIRE file in A AFTER learner predictions from file 02.
-- NULL is a missing row, NOT a status called NULL.
USE meridian_retail;
SELECT s.order_id,
 s.delivery_status AS source_status,
 e.delivery_status AS export_status,
 l.delivery_status AS local_status,
 DATE_FORMAT(s.source_updated_at,'%Y-%m-%d %H:%i') AS source_updated_at,
 DATE_FORMAT(e.exported_at,'%Y-%m-%d %H:%i') AS exported_at,
 DATE_FORMAT(l.synced_at,'%Y-%m-%d %H:%i') AS synced_at,
 CASE
  WHEN l.order_id IS NULL THEN 'MISSING_LOCAL'
  WHEN e.order_id IS NULL THEN 'MISSING_EXPORT'
  WHEN e.delivery_status <> s.delivery_status AND s.source_updated_at <= e.exported_at THEN 'CONFLICT_REVIEW'
  WHEN l.delivery_status <> s.delivery_status AND s.source_updated_at > l.synced_at THEN 'LOCAL_STALE_AFTER_SOURCE_CHANGE'
  WHEN l.delivery_status <> s.delivery_status THEN 'DIFFERENCE_REVIEW'
  WHEN e.delivery_status <> s.delivery_status THEN 'EXPORT_OLDER_OR_DIFFERENT'
  ELSE 'MATCHES_SOURCE'
 END AS investigation_label
FROM class12_legacy_orders s
LEFT JOIN class12_nightly_export e ON e.order_id=s.order_id
LEFT JOIN class12_local_orders l ON l.order_id=s.order_id
WHERE s.order_id IN('MR-501','MR-502','MR-000001','MR-000002','MR-000003','MR-000004')
ORDER BY FIELD(s.order_id,'MR-501','MR-502','MR-000001','MR-000002','MR-000003','MR-000004');
-- Label is a classroom triage aid, not a policy engine or proof of root cause.
