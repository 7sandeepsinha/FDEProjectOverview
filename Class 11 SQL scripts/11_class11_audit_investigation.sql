-- Section 10 | Run entire file in A. Prepared SYNTHETIC evidence, not real SQL logs.
USE meridian_retail;
SELECT event_id,happened_at,actor,action_name,object_name,
       case_id,rows_reported,permission_result,ticket_reference,evidence_origin
FROM class11_audit_events
ORDER BY happened_at,event_id;
SELECT actor,object_name,COUNT(*) AS events,
       SUM(COALESCE(rows_reported,0)) AS sum_reported_rows
FROM class11_audit_events
WHERE happened_at >= '2026-09-20 09:00:00'
  AND happened_at <  '2026-09-20 09:10:00'
GROUP BY actor,object_name
ORDER BY events DESC;
SELECT event_id,happened_at,actor,rows_reported,
       permission_result,ticket_reference
FROM class11_audit_events
WHERE actor='fde11_support_demo'
ORDER BY happened_at;
-- An ALLOWED event is not proof of legitimate business purpose.
-- No classroom SELECT/denial is automatically being logged into this table.
