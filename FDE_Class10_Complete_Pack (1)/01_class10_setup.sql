-- ONE TIME, before class. Execute only after 00 preflight passes.
-- Workbench must STOP ON FIRST ERROR. Never continue after an error.
-- Requires no active transactions; DDL has implicit commits.
-- Creates only the named Class 10 teaching additions; no DROP DATABASE.
USE meridian_retail;
-- Fail if source count/identity coverage differs from the expected snapshot.
CREATE TEMPORARY TABLE class10_setup_guard (
  ok INT NOT NULL CHECK (ok=1)
) ENGINE=InnoDB;
INSERT INTO class10_setup_guard
SELECT IF(COUNT(*)=25000 AND COUNT(DISTINCT case_id)=25000,1,0)
FROM case_context_snapshot;
INSERT INTO class10_setup_guard
SELECT IF(COUNT(*)=0,1,0) FROM support_cases
WHERE case_id IN ('MCS-C10-RC','MCS-C10-RR','MCS-C10-LK','MCS-C10-OK');

CREATE TABLE class10_case_search (
  observation_id INT UNSIGNED NOT NULL PRIMARY KEY,
  source_case_id VARCHAR(12) NOT NULL,
  customer_id VARCHAR(12) NULL,
  review_status VARCHAR(20) NOT NULL,
  received_at DATETIME NOT NULL,
  case_type VARCHAR(20) NOT NULL,
  context_note VARCHAR(220) NOT NULL,
  CHECK (review_status IN ('PENDING','APPROVED','REJECTED'))
) ENGINE=InnoDB;
-- No FKs: a frozen synthetic reporting fixture, not the operational model.
-- Grain: ONE simulated observation of ONE source case in ONE workload round.
-- 25000 source cases x 20 rounds = 500000 observations, NOT 500000 cases.
-- Source identity/customer/case type come from the Class 8 snapshot.
-- Status/date and note below are SYNTHETIC workload values, not new evidence.
START TRANSACTION;
INSERT INTO class10_case_search
 (observation_id,source_case_id,customer_id,review_status,received_at,case_type,context_note)
SELECT (r.round_no*25000)+s.seq, s.case_id,s.customer_id,
       CASE MOD(s.seq+r.round_no,10)
         WHEN 0 THEN 'REJECTED'
         WHEN 1 THEN 'APPROVED'
         WHEN 2 THEN 'APPROVED'
         ELSE 'PENDING' END,
       DATE_ADD(s.received_at, INTERVAL (r.round_no*7) DAY), s.case_type,
       RPAD(CONCAT('SYNTHETIC Class 10 observation of ',s.case_id),200,'.')
FROM (SELECT ROW_NUMBER() OVER (ORDER BY case_id) AS seq,
             case_id,customer_id,case_type,received_at
      FROM case_context_snapshot) AS s
CROSS JOIN (
 SELECT ones.d + tens.d*10 AS round_no
 FROM (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
       UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL
       SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS ones
 CROSS JOIN (SELECT 0 d UNION ALL SELECT 1) AS tens
) AS r;
INSERT INTO support_cases
 (case_id,order_id,received_at,customer_question,case_type,review_status,extract_generated_at)
VALUES
 ('MCS-C10-RC',NULL,'2026-09-18 12:00:00','SYNTHETIC read committed teaching case','GENERAL','PENDING','2026-09-18 12:00:00'),
 ('MCS-C10-RR',NULL,'2026-09-18 12:00:00','SYNTHETIC repeatable read teaching case','GENERAL','PENDING','2026-09-18 12:00:00'),
 ('MCS-C10-LK',NULL,'2026-09-18 12:00:00','SYNTHETIC short lock teaching case','GENERAL','PENDING','2026-09-18 12:00:00'),
 ('MCS-C10-OK',NULL,'2026-09-18 12:00:00','SYNTHETIC unrelated teaching case','GENERAL','PENDING','2026-09-18 12:00:00');
COMMIT;
DROP TEMPORARY TABLE class10_setup_guard;
ANALYZE TABLE class10_case_search;
SELECT COUNT(*) AS observation_rows,
 COUNT(DISTINCT source_case_id) AS source_cases FROM class10_case_search;
SHOW INDEX FROM class10_case_search;
SELECT case_id,review_status FROM support_cases WHERE case_id LIKE 'MCS-C10-%';
-- Expected: 500000 / 25000; only PRIMARY; four PENDING rows.
-- If DML fails before COMMIT: ROLLBACK and stop. The created table remains.
-- If any setup step fails, do not rerun whole file or reset core Meridian.
-- Inspect the named additions on the disposable copy before repairing offline.
