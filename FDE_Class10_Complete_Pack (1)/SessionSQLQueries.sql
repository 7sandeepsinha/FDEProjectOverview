SET autocommit=1;
USE meridian_retail;

SELECT COUNT(*) AS observation_rows, COUNT(DISTINCT source_case_id) AS source_cases
FROM class10_case_search;
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


SELECT COUNT(*) AS observation_rows, COUNT(DISTINCT source_case_id) AS source_cases
FROM class10_case_search;



SELECT COUNT(*) AS matching_observations
FROM class10_case_search
WHERE customer_id='CUS-000001'; -- 88 ms -> 1ms

EXPLAIN FORMAT=TRADITIONAL
SELECT COUNT(*) AS matching_observations
FROM class10_case_search
WHERE customer_id = 'CUS-000001';

CREATE INDEX idx_c10_customer ON class10_case_search(customer_id);

CREATE INDEX idx_c10_customer_status_date
ON class10_case_search(customer_id,review_status,received_at);

EXPLAIN ANALYZE
SELECT observation_id, source_case_id, received_at, context_note
FROM class10_case_search
WHERE customer_id = 'CUS-000001' AND review_status = 'PENDING'
  AND received_at >= '2026-09-01' AND received_at < '2026-10-01'
ORDER BY received_at, observation_id;

-- -> Sort: class10_case_search.received_at,
-- class10_case_search.observation_id  
-- (cost=27.7 rows=60) (actual time=0.392..0.393 rows=12 loops=1)
    

-- -> Filter: ((class10_case_search.review_status = 'PENDING') 
-- and (class10_case_search.received_at >= TIMESTAMP'2026-09-01 00:00:00') and (class10_case_search.received_at < TIMESTAMP'2026-10-01 00:00:00'))  (cost=27.7 rows=60) (actual time=0.112..0.38 rows=12 loops=1)
    
    
-- -> Index lookup on class10_case_search
--  using idx_c10_customer (customer_id = 'CUS-000001')
--  (cost=27.7 rows=60) (actual time=0.11..0.368 rows=60 loops=1)


----------------------------------------------------------------------


-- Session settings this file changes; Step 8 restores them.
SET @delta_saved_safe_updates = @@SESSION.sql_safe_updates;
SET @delta_saved_cte_depth = @@SESSION.cte_max_recursion_depth;

USE meridian_retail;

DROP TEMPORARY TABLE IF EXISTS delta_guard;
CREATE TEMPORARY TABLE delta_guard (
    guard_name VARCHAR(60) NOT NULL,
    ok         INT         NOT NULL,
    CONSTRAINT delta_guard_must_pass CHECK (ok = 1)
) ENGINE = InnoDB;

INSERT INTO delta_guard
SELECT 'A: earlier-class row counts',
       IF((SELECT COUNT(*) FROM orders) = 20000
          AND (SELECT COUNT(*) FROM support_cases) = 25000
          AND (SELECT COUNT(*) FROM human_reviews) = 10000
          AND (SELECT COUNT(*) FROM validation_rules) = 12, 1, 0);

-- Guard B: Class 8 already made issue_id the primary key of issue_records.
INSERT INTO delta_guard
SELECT 'B: issue_records primary key is issue_id',
       IF((SELECT GROUP_CONCAT(column_name)
           FROM information_schema.key_column_usage
           WHERE table_schema = DATABASE()
             AND table_name = 'issue_records'
             AND constraint_name = 'PRIMARY') = 'issue_id', 1, 0);

-- Guard C: none of the remaining Class 8 objects exist yet.
INSERT INTO delta_guard
SELECT 'C: remaining Class 8 objects not built yet',
       IF((SELECT COUNT(*) FROM information_schema.tables
           WHERE table_schema = DATABASE()
             AND table_name IN ('customers', 'products', 'case_routes',
                                'case_context_snapshot', 'vw_case_context')) = 0
          AND (SELECT COUNT(*) FROM information_schema.columns
               WHERE table_schema = DATABASE()
                 AND table_name = 'orders'
                 AND column_name IN ('customer_id', 'customer_link_source',
                                     'product_id')) = 0, 1, 0);

-- Guard D: apart from ISS-DEMO rows, exactly the 25,000 original issues
-- remain: one per case, each with its original ID.
INSERT INTO delta_guard
SELECT 'D: 25000 original issues besides ISS-DEMO rows',
       IF(COUNT(*) = 25000
          AND COUNT(DISTINCT case_id) = 25000
          AND SUM(issue_id = CONCAT('ISS-', SUBSTRING(case_id, 5))) = 25000, 1, 0)
FROM issue_records
WHERE issue_id NOT LIKE 'ISS-DEMO-%';

SELECT guard_name, ok FROM delta_guard;


CREATE TEMPORARY TABLE delta_original_issue_evidence AS
SELECT issue_id, case_id, issue_type, issue_details, reported_delivery_date,
       evidence_status, extract_generated_at
FROM issue_records
WHERE issue_id NOT LIKE 'ISS-DEMO-%';

-- Only after every guard passed: allow the intended full-table backfills.
SET SESSION sql_safe_updates = 0;

-- ---------------------------------------------------------------------------
-- Step 1. Remove the hand-made demo issue row(s)
-- ---------------------------------------------------------------------------
-- In Class 8 we inserted ISS-DEMO-502 by hand to show one case holding two
-- issues. Step 4 now adds the official second issues, including ISSX-000001
-- for MCS-000001, so MCS-000001 still has two issues afterwards. Left in place,
-- the demo row would also collide with the generated ID ISSX-000001.

SELECT issue_id, case_id, issue_type, issue_details
FROM issue_records
WHERE issue_id LIKE 'ISS-DEMO-%';

DELETE FROM issue_records
WHERE issue_id LIKE 'ISS-DEMO-%';


CREATE TABLE customers (
    customer_id VARCHAR(12)  NOT NULL,
    email       VARCHAR(150) NOT NULL,
    identity_source VARCHAR(30) NOT NULL DEFAULT 'SYNTHETIC_TEACHING',
    CONSTRAINT chk_customers_identity_source
        CHECK (identity_source IN ('SYNTHETIC_TEACHING', 'AUTHORITATIVE')),
    CONSTRAINT pk_customers PRIMARY KEY (customer_id),
    CONSTRAINT uq_customers_email UNIQUE (email)
) ENGINE = InnoDB;

SET SESSION cte_max_recursion_depth = 15001;

INSERT INTO customers (customer_id, email)
WITH RECURSIVE numbers AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1
    FROM numbers
    WHERE n < 15000
)
SELECT
    CONCAT('CUS-', LPAD(n, 6, '0')) AS customer_id,
    CONCAT('customer', LPAD(n, 6, '0'), '@example.test') AS email
FROM numbers;


ALTER TABLE orders
    ADD COLUMN customer_id VARCHAR(12) NULL AFTER order_id,
    ADD COLUMN customer_link_source VARCHAR(30) NOT NULL
        DEFAULT 'SYNTHETIC_TEACHING' AFTER customer_id,
    ADD CONSTRAINT chk_orders_customer_link_source
        CHECK (customer_link_source IN ('SYNTHETIC_TEACHING', 'AUTHORITATIVE'));

UPDATE orders
SET customer_id = CONCAT(
    'CUS-',
    LPAD(
        1 + MOD(
            CAST(SUBSTRING_INDEX(order_id, '-', -1) AS UNSIGNED) - 1,
            15000
        ),
        6,
        '0'
    )
);

ALTER TABLE orders
    MODIFY customer_id VARCHAR(12) NOT NULL,
    ADD CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT;


CREATE TABLE products (
    product_id   VARCHAR(12)  NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    CONSTRAINT pk_products PRIMARY KEY (product_id),
    CONSTRAINT uq_products_name UNIQUE (product_name)
) ENGINE = InnoDB;

INSERT INTO products (product_id, product_name)
SELECT
    CONCAT('PRD-', LPAD(ROW_NUMBER() OVER (ORDER BY product_name), 3, '0')) AS product_id,
    product_name
FROM (
    SELECT DISTINCT product AS product_name
    FROM orders
) AS distinct_products;

UPDATE orders AS o
JOIN products AS p
    ON p.product_name = o.product
SET o.product_id = p.product_id;


ALTER TABLE orders
    MODIFY product_id VARCHAR(12) NOT NULL,
    ADD CONSTRAINT fk_orders_product
        FOREIGN KEY (product_id) REFERENCES products (product_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT;

INSERT INTO issue_records (
    issue_id,
    case_id,
    issue_type,
    issue_details,
    reported_delivery_date,
    evidence_status,
    extract_generated_at
)
SELECT
    CONCAT('ISSX-', RIGHT(ir.case_id, 6)) AS issue_id,
    ir.case_id,
    CASE
        WHEN ir.issue_type = 'RETURN_REQUEST'  THEN 'REFUND_DELAY'
        WHEN ir.issue_type = 'REFUND_DELAY'    THEN 'RETURN_REQUEST'
        WHEN ir.issue_type = 'HARDWARE_FAULT'  THEN 'PHYSICAL_DAMAGE'
        WHEN ir.issue_type = 'PHYSICAL_DAMAGE' THEN 'HARDWARE_FAULT'
        WHEN ir.issue_type = 'LATE_DELIVERY'   THEN 'MISSING_ITEM'
        WHEN ir.issue_type = 'MISSING_ITEM'    THEN 'WRONG_ITEM'
        WHEN ir.issue_type = 'WRONG_ITEM'      THEN 'LATE_DELIVERY'
        WHEN ir.issue_type = 'DOUBLE_CHARGE'   THEN 'PAYMENT_FAILURE'
        WHEN ir.issue_type = 'PAYMENT_FAILURE' THEN 'REFUND_DELAY'
        ELSE 'USER_GUIDANCE'
    END AS issue_type,
    CONCAT(
        'Secondary issue captured during Class 8 model evolution. Original issue: ',
        ir.issue_type
    ) AS issue_details,
    ir.reported_delivery_date,
    ir.evidence_status,
    ir.extract_generated_at
FROM issue_records AS ir
WHERE ir.issue_id LIKE 'ISS-%'
  AND ir.case_id LIKE 'MCS-0%'
ORDER BY ir.case_id
LIMIT 1470;


CREATE TABLE case_routes (
    route_id         VARCHAR(20) NOT NULL,
    case_id          VARCHAR(12) NOT NULL,
    rule_id          VARCHAR(10) NOT NULL,
    source_review_id VARCHAR(14) NULL,
    routed_at        DATETIME    NOT NULL,
    event_source     VARCHAR(30) NOT NULL,
    timestamp_basis  VARCHAR(30) NOT NULL,
    CONSTRAINT chk_case_routes_provenance CHECK (
        (event_source = 'LEGACY_REVIEW'
         AND timestamp_basis = 'REVIEW_TIME_PROXY')
        OR
        (event_source = 'OBSERVED_ROUTE'
         AND timestamp_basis = 'ROUTE_EVENT_TIME')
    ),
    CONSTRAINT pk_case_routes PRIMARY KEY (route_id),
    CONSTRAINT uq_case_routes_source_review UNIQUE (source_review_id),
    CONSTRAINT fk_case_routes_case
        FOREIGN KEY (case_id) REFERENCES support_cases (case_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_case_routes_rule
        FOREIGN KEY (rule_id) REFERENCES validation_rules (rule_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_case_routes_review
        FOREIGN KEY (source_review_id) REFERENCES human_reviews (review_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE = InnoDB;


INSERT INTO case_routes (
    route_id,
    case_id,
    rule_id,
    source_review_id,
    routed_at,
    event_source,
    timestamp_basis
)
SELECT
    CONCAT('RT-', hr.review_id) AS route_id,
    hr.case_id,
    hr.triggered_rule_id,
    hr.review_id,
    hr.reviewed_at,
    'LEGACY_REVIEW',
    'REVIEW_TIME_PROXY'
FROM human_reviews AS hr
WHERE hr.triggered_rule_id IS NOT NULL;


CREATE OR REPLACE VIEW vw_case_context AS
SELECT
    sc.case_id,
    sc.order_id,
    o.customer_id,
    o.product_id,
    p.product_name,
    sc.received_at,
    sc.case_type,
    sc.review_status
FROM support_cases AS sc
LEFT JOIN orders AS o
    ON o.order_id = sc.order_id
LEFT JOIN products AS p
    ON p.product_id = o.product_id;


CREATE TABLE case_context_snapshot (
    case_id               VARCHAR(12)  NOT NULL,
    order_id              VARCHAR(12)  NULL,
    customer_id           VARCHAR(12)  NULL,
    product_id            VARCHAR(12)  NULL,
    product_name          VARCHAR(100) NULL,
    case_type             VARCHAR(20)  NOT NULL,
    review_status         VARCHAR(20)  NOT NULL,
    received_at           DATETIME     NOT NULL,
    snapshot_generated_at DATETIME     NOT NULL,
    CONSTRAINT pk_case_context_snapshot PRIMARY KEY (case_id)
) ENGINE = InnoDB;

SET @class8_snapshot_generated_at = UTC_TIMESTAMP();


INSERT INTO case_context_snapshot (
    case_id,
    order_id,
    customer_id,
    product_id,
    product_name,
    case_type,
    review_status,
    received_at,
    snapshot_generated_at
)
SELECT
    case_id,
    order_id,
    customer_id,
    product_id,
    product_name,
    case_type,
    review_status,
    received_at,
    @class8_snapshot_generated_at
FROM vw_case_context;


-- CHECKS 
-- Every actual_rows should equal expected_rows
SELECT 'customers' AS object_name, COUNT(*) AS actual_rows, 15000 AS expected_rows
FROM customers
UNION ALL
SELECT 'products', COUNT(*), 16 FROM products
UNION ALL
SELECT 'issue_records', COUNT(*), 26470 FROM issue_records
UNION ALL
SELECT 'case_routes imported evidence', COUNT(*), 3564 FROM case_routes
UNION ALL
SELECT 'vw_case_context', COUNT(*), 25000 FROM vw_case_context
UNION ALL
SELECT 'case_context_snapshot', COUNT(*), 25000 FROM case_context_snapshot;

-- Every customer and product link should resolve. Expected: 0.
SELECT COUNT(*) AS orphan_order_dimensions
FROM orders AS o
LEFT JOIN customers AS c
    ON c.customer_id = o.customer_id
LEFT JOIN products AS p
    ON p.product_id = o.product_id
WHERE c.customer_id IS NULL
   OR p.product_id IS NULL;

-- Exactly 1,470 cases now have a second issue row. Expected: 1470.
SELECT COUNT(*) AS cases_with_multiple_issues
FROM (
    SELECT case_id
    FROM issue_records
    GROUP BY case_id
    HAVING COUNT(*) > 1
) AS multi_issue_cases;

-- MCS-000001 still has two issues, now the official way:
-- ISS-000001 and ISSX-000001.
SELECT issue_id, case_id, issue_type, evidence_status
FROM issue_records
WHERE case_id = 'MCS-000001'
ORDER BY issue_id;

-- Route migration should preserve every non-null legacy trigger. Expected: 0.
SELECT COUNT(*) AS route_migration_mismatches
FROM human_reviews AS hr
LEFT JOIN case_routes AS cr
    ON cr.source_review_id = hr.review_id
WHERE hr.triggered_rule_id IS NOT NULL
  AND (
      cr.route_id IS NULL
      OR cr.rule_id <> hr.triggered_rule_id
      OR cr.case_id <> hr.case_id
      OR cr.event_source <> 'LEGACY_REVIEW'
      OR cr.timestamp_basis <> 'REVIEW_TIME_PROXY'
      OR cr.routed_at <> hr.reviewed_at
  );

-- Every original issue field was preserved, not only the row count. Expected: 0.
SELECT COUNT(*) AS original_issue_preservation_failures
FROM delta_original_issue_evidence AS b
LEFT JOIN issue_records AS ir
    ON ir.issue_id = b.issue_id
WHERE ir.issue_id IS NULL
   OR NOT (
       CAST(ir.case_id AS BINARY) <=> CAST(b.case_id AS BINARY)
       AND CAST(ir.issue_type AS BINARY) <=> CAST(b.issue_type AS BINARY)
       AND CAST(ir.issue_details AS BINARY) <=> CAST(b.issue_details AS BINARY)
       AND ir.reported_delivery_date <=> b.reported_delivery_date
       AND CAST(ir.evidence_status AS BINARY) <=> CAST(b.evidence_status AS BINARY)
       AND ir.extract_generated_at <=> b.extract_generated_at
   );

DROP TEMPORARY TABLE delta_original_issue_evidence;
DROP TEMPORARY TABLE delta_guard;

SET SESSION sql_safe_updates = @delta_saved_safe_updates;
SET SESSION cte_max_recursion_depth = @delta_saved_cte_depth;

------------------------------------------------------------------------------------------

USE meridian_retail;

SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = DATABASE()
ORDER BY table_type, table_name;

SELECT item, needed, currently,
       IF(currently = needed, 'OK', 'TO DO') AS status
FROM (
    SELECT 1 AS n, 'orders rows' AS item, '20000' AS needed,
           CAST((SELECT COUNT(*) FROM orders) AS CHAR) AS currently
    UNION ALL
    SELECT 2, 'support_cases rows (original cases)', '25000',
           CAST((SELECT COUNT(*) FROM support_cases
                 WHERE case_id NOT LIKE 'MCS-C10-%') AS CHAR)
    UNION ALL
    SELECT 3, 'human_reviews rows (original reviews)', '10000',
           CAST((SELECT COUNT(*) FROM human_reviews
                 WHERE review_id NOT LIKE 'MHR-C10-%') AS CHAR)
    UNION ALL
    SELECT 4, 'validation_rules rows', '12',
           CAST((SELECT COUNT(*) FROM validation_rules) AS CHAR)
    UNION ALL
    SELECT 5, 'support_cases columns (no extra version column)', '7',
           CAST((SELECT COUNT(*) FROM information_schema.columns
                 WHERE table_schema = DATABASE()
                   AND table_name = 'support_cases') AS CHAR)
    UNION ALL
    SELECT 6, 'issue_records primary key', 'issue_id',
           (SELECT COALESCE(GROUP_CONCAT(column_name ORDER BY ordinal_position), '(none)')
            FROM information_schema.key_column_usage
            WHERE table_schema = DATABASE()
              AND table_name = 'issue_records'
              AND constraint_name = 'PRIMARY')
    UNION ALL
    SELECT 7, 'issue_records rows (25000 original + 1470 second issues)', '26470',
           CAST((SELECT COUNT(*) FROM issue_records) AS CHAR)
    UNION ALL
    SELECT 8, 'customers table', 'present',
           (SELECT IF(COUNT(*) = 1, 'present', 'missing')
            FROM information_schema.tables
            WHERE table_schema = DATABASE() AND table_name = 'customers')
    UNION ALL
    SELECT 9, 'orders.customer_id column', 'present',
           (SELECT IF(COUNT(*) = 1, 'present', 'missing')
            FROM information_schema.columns
            WHERE table_schema = DATABASE() AND table_name = 'orders'
              AND column_name = 'customer_id')
    UNION ALL
    SELECT 10, 'products table', 'present',
           (SELECT IF(COUNT(*) = 1, 'present', 'missing')
            FROM information_schema.tables
            WHERE table_schema = DATABASE() AND table_name = 'products')
    UNION ALL
    SELECT 11, 'orders.product_id column', 'present',
           (SELECT IF(COUNT(*) = 1, 'present', 'missing')
            FROM information_schema.columns
            WHERE table_schema = DATABASE() AND table_name = 'orders'
              AND column_name = 'product_id')
    UNION ALL
    SELECT 12, 'case_routes table', 'present',
           (SELECT IF(COUNT(*) = 1, 'present', 'missing')
            FROM information_schema.tables
            WHERE table_schema = DATABASE() AND table_name = 'case_routes')
    UNION ALL
    SELECT 13, 'vw_case_context view', 'present',
           (SELECT IF(COUNT(*) = 1, 'present', 'missing')
            FROM information_schema.tables
            WHERE table_schema = DATABASE() AND table_name = 'vw_case_context')
    UNION ALL
    SELECT 14, 'case_context_snapshot table', 'present',
           (SELECT IF(COUNT(*) = 1, 'present', 'missing')
            FROM information_schema.tables
            WHERE table_schema = DATABASE() AND table_name = 'case_context_snapshot')
) AS checklist
ORDER BY n;


------------------------------------

SELECT 
    CONNECTION_ID() AS session_id,
    @@autocommit AS session_autocommit,
    @@transaction_isolation AS session_isolation;

SET autocommit = 0;

SET @@session.transaction_isolation = 'SERIALIZABLE';

USE meridian_retail;

START TRANSACTION;

SELECT * FROM orders o WHERE o.order_id  = "MR-000001" FOR UPDATE;

COMMIT;

-- Apply to Meridian 
-- Isolation levels are different on both session 

SELECT @@transaction_isolation;
SELECT @@autocommit;

-- TRANSACTION ISOLATION LEVEL 
-- READ UNCOMMITTED
-- READ COMMITTED
-- REPEATABLE READ 
-- SERIALIZABLE 

-- default - REPEATABLE READ - MySQL
-- default - READ COMMITTED - Postgres
-- default - READ COMMITTED - SQL Server  

SELECT CONNECTION_ID();

SELECT 
    CONNECTION_ID() AS session_id,
    @@autocommit AS session_autocommit,
    @@transaction_isolation AS session_isolation;

SET autocommit = 0;

SET @@session.transaction_isolation = 'SERIALIZABLE';

USE meridian_retail;

START TRANSACTION;

UPDATE orders o 
SET payment_status = "PAID"
WHERE o.order_id  = "MR-000001";

SELECT * FROM orders o WHERE o.order_id  = "MR-000001";

COMMIT;
ROLLBACK;