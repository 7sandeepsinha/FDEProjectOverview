-- CLASS 12 | ONE-TIME teaching setup | RUN ENTIRE FILE in A, only after 00 preflight passes.
-- Adds FOUR class12_ tables inside existing meridian_retail; no DROP DATABASE.
-- Simulates an on-prem legacy source, a nightly file, and a local copy.
-- No actual firewall, VPN, SFTP transfer or live replication is performed.
-- Dataset values/statuses are invented for this teaching simulation; selected order IDs exist in Meridian.
-- The SOURCE in this scenario is authoritative by the scenario's business contract, NOT by MySQL location.
-- Fixed scenario clock: 2026-09-20 10:00:00. Never use NOW() to compare synthetic timestamps.
-- DDL commits implicitly. If setup errors, STOP; do not blindly rerun it.
USE meridian_retail;
CREATE TABLE class12_legacy_orders (
 order_id VARCHAR(12) PRIMARY KEY,
 delivery_status VARCHAR(24) NOT NULL,
 source_updated_at DATETIME NOT NULL,
 evidence_origin VARCHAR(32) NOT NULL DEFAULT 'SYNTHETIC_LEGACY',
 CONSTRAINT fk_c12_legacy_order FOREIGN KEY(order_id) REFERENCES orders(order_id),
 CONSTRAINT chk_c12_legacy_status CHECK(delivery_status IN ('PROCESSING','IN_TRANSIT','OUT_FOR_DELIVERY','DELIVERED','CANCELLED'))
) ENGINE=InnoDB;
CREATE TABLE class12_nightly_export (
 order_id VARCHAR(12) PRIMARY KEY,
 delivery_status VARCHAR(24) NOT NULL,
 exported_at DATETIME NOT NULL,
 evidence_origin VARCHAR(32) NOT NULL DEFAULT 'SYNTHETIC_FILE',
 CONSTRAINT fk_c12_export_order FOREIGN KEY(order_id) REFERENCES orders(order_id)
) ENGINE=InnoDB;
CREATE TABLE class12_local_orders (
 order_id VARCHAR(12) PRIMARY KEY,
 delivery_status VARCHAR(24) NOT NULL,
 synced_at DATETIME NOT NULL,
 evidence_origin VARCHAR(32) NOT NULL DEFAULT 'SYNTHETIC_LOCAL_COPY',
 CONSTRAINT fk_c12_local_order FOREIGN KEY(order_id) REFERENCES orders(order_id)
) ENGINE=InnoDB;
CREATE TABLE class12_sync_runs (
 run_id VARCHAR(20) PRIMARY KEY,
 pipeline_name VARCHAR(32) NOT NULL,
 started_at DATETIME NOT NULL,
 finished_at DATETIME NULL,
 outcome VARCHAR(12) NOT NULL,
 rows_reported SMALLINT NULL,
 note VARCHAR(140) NOT NULL,
 CONSTRAINT chk_c12_sync_outcome CHECK(outcome IN('SUCCESS','FAILED'))
) ENGINE=InnoDB;
-- Use 22 existing generated order IDs plus original anchors MR-501 / MR-502.
-- This subset is only to anchor the scenario to familiar Meridian identifiers.
INSERT INTO class12_legacy_orders(order_id,delivery_status,source_updated_at)
SELECT o.order_id,
 CASE o.order_id
   WHEN 'MR-501' THEN 'DELIVERED'
   WHEN 'MR-502' THEN 'DELIVERED'
   WHEN 'MR-000001' THEN 'IN_TRANSIT'
   WHEN 'MR-000002' THEN 'CANCELLED'
   WHEN 'MR-000003' THEN 'OUT_FOR_DELIVERY'
   WHEN 'MR-000004' THEN 'PROCESSING'
   ELSE CASE WHEN MOD(CAST(RIGHT(o.order_id,6) AS UNSIGNED),3)=0 THEN 'DELIVERED'
             WHEN MOD(CAST(RIGHT(o.order_id,6) AS UNSIGNED),3)=1 THEN 'PROCESSING'
             ELSE 'IN_TRANSIT' END
 END,
 CASE o.order_id
   WHEN 'MR-502' THEN '2026-09-20 09:50:00'
   WHEN 'MR-000002' THEN '2026-09-18 18:00:00'
   WHEN 'MR-000003' THEN '2026-09-20 09:49:00'
   WHEN 'MR-000004' THEN '2026-09-19 21:00:00'
   ELSE '2026-09-19 20:00:00'
 END
FROM orders o
WHERE o.order_id IN ('MR-501','MR-502','MR-000001','MR-000002','MR-000003','MR-000004','MR-000005','MR-000006',
'MR-000007','MR-000008','MR-000009','MR-000010','MR-000011','MR-000012','MR-000013','MR-000014',
'MR-000015','MR-000016','MR-000017','MR-000018','MR-000019','MR-000020','MR-000021','MR-000022');
-- The previous-night export is missing MR-000004. MR-000002 is intentionally inconsistent
-- even though its source value was updated BEFORE the export, so simple timing cannot resolve it.
INSERT INTO class12_nightly_export(order_id,delivery_status,exported_at)
SELECT order_id,
 CASE order_id
  WHEN 'MR-502' THEN 'IN_TRANSIT'   -- older than the next-morning source update
  WHEN 'MR-000002' THEN 'DELIVERED' -- deliberate discrepancy requiring ownership review
  WHEN 'MR-000003' THEN 'PROCESSING' -- older than the next-morning source update
  ELSE delivery_status
 END,
 '2026-09-19 23:00:00'
FROM class12_legacy_orders WHERE order_id <> 'MR-000004';
-- Local consumer copy last completed at 09:42 and missed MR-000001.
-- Some source changes occurred later at 09:49 / 09:50, so the copy did not include them.
INSERT INTO class12_local_orders(order_id,delivery_status,synced_at)
SELECT order_id,
 CASE order_id
  WHEN 'MR-502' THEN 'IN_TRANSIT'
  WHEN 'MR-000003' THEN 'PROCESSING'
  ELSE delivery_status
 END,
 '2026-09-20 09:42:00'
FROM class12_legacy_orders WHERE order_id <> 'MR-000001';
INSERT INTO class12_sync_runs(run_id,pipeline_name,started_at,finished_at,outcome,rows_reported,note) VALUES
 ('C12-FILE-01','NIGHTLY_EXPORT','2026-09-19 22:58:00','2026-09-19 23:00:00','SUCCESS',23,'Simulated nightly export; missing MR-000004'),
 ('C12-LOCAL-01','LOCAL_COPY','2026-09-20 09:18:00','2026-09-20 09:20:00','SUCCESS',23,'Earlier simulated local sync'),
 ('C12-LOCAL-02','LOCAL_COPY','2026-09-20 09:40:00','2026-09-20 09:42:00','SUCCESS',23,'Last successful local copy refresh'),
 ('C12-LOCAL-03','LOCAL_COPY','2026-09-20 09:55:00',NULL,'FAILED',NULL,'Simulated source unavailable; no fresh copy published');
SELECT COUNT(*) AS source_rows FROM class12_legacy_orders;
SELECT COUNT(*) AS export_rows FROM class12_nightly_export;
SELECT COUNT(*) AS local_rows FROM class12_local_orders;
SELECT COUNT(*) AS sync_run_rows FROM class12_sync_runs;
-- Expected 24 / 23 / 23 / 4. Stop if not.
