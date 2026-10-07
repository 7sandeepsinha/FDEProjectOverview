-- CLASS 8 ONLY: RESET CLASS 8 CHANGES, THEN MIGRATE AND VERIFY
-- MySQL 8.0.18+. Run the entire file against meridian_retail.
-- Requires the existing Class 6-7 dataset. Does NOT create or seed earlier tables.
-- Removes Class 8 customers/products/routes/snapshot and generated secondary issues.
-- Preserves orders, support_cases, human_reviews, validation_rules and original issues.
-- Class 8 manual edits and generated data are discarded. Use the classroom DB only.
-- Handles the known partial stages of the supplied Class 8 migration.
-- Unexpected schema/data errors stop the CALL; DDL cannot be rolled back.
-- Static review only: execution on your MySQL instance is still required.

USE meridian_retail;
DROP PROCEDURE IF EXISTS class8_assert_baseline;
DROP PROCEDURE IF EXISTS class8_only_reset_and_run;
SET @class8_run_status = 'NOT_RUN';
DELIMITER $$
CREATE PROCEDURE class8_only_reset_and_run()
SQL SECURITY INVOKER
BEGIN
 DECLARE v_safe INT DEFAULT @@SESSION.sql_safe_updates;
 DECLARE v_depth INT DEFAULT @@SESSION.cte_max_recursion_depth;
 DECLARE v_stage VARCHAR(30) DEFAULT 'PREFLIGHT';
 DECLARE v_error TEXT;
 DECLARE v_message VARCHAR(128);
 DECLARE EXIT HANDLER FOR SQLEXCEPTION
 BEGIN
  GET DIAGNOSTICS CONDITION 1 v_error = MESSAGE_TEXT;
  ROLLBACK;
  SET SESSION sql_safe_updates = v_safe;
  SET SESSION cte_max_recursion_depth = v_depth;
  SET @class8_run_status = CONCAT('FAILED: ', v_stage);
  SET v_message = LEFT(CONCAT('Class 8 ', v_stage, ': ', v_error), 128);
  RESIGNAL SET MESSAGE_TEXT = v_message;
 END;
 SET @class8_run_status = 'RUNNING';
 IF (SELECT COUNT(*) FROM orders) <> 20000
 OR (SELECT COUNT(*) FROM support_cases) <> 25000
 OR (SELECT COUNT(*) FROM human_reviews) <> 10000
 OR (SELECT COUNT(*) FROM validation_rules) <> 12 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Earlier-class dataset is missing or changed; this file does not reseed it';
 END IF;
 SET SESSION sql_safe_updates = 0;
 SET v_stage = 'RESET_CLASS8';
 DROP TEMPORARY TABLE IF EXISTS class8_original_issue_evidence;
 DROP VIEW IF EXISTS vw_case_context;
 DROP TABLE IF EXISTS case_context_snapshot;
 DROP TABLE IF EXISTS case_routes;

 -- Undo only the supplied Class 8 issue migration.
 IF EXISTS (SELECT 1 FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name = 'issue_records' AND column_name = 'issue_id') THEN
  -- Stop before deleting if unrecognized new issues are present.
  IF EXISTS (SELECT 1 FROM issue_records
    WHERE issue_id IS NOT NULL
    AND issue_id NOT LIKE 'ISSX-%'
    AND issue_id <> CONCAT('ISS-', SUBSTRING(case_id, 5))) THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unrecognized issue IDs: reset stopped to preserve manual data';
  END IF;
  DELETE FROM issue_records WHERE issue_id LIKE 'ISSX-%';
  IF (SELECT COUNT(*) FROM issue_records) <> 25000
    OR (SELECT COUNT(DISTINCT case_id) FROM issue_records) <> 25000 THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Original issue rows are incomplete; cannot reset without earlier seed';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.key_column_usage
    WHERE table_schema = DATABASE() AND table_name = 'issue_records'
      AND constraint_name = 'PRIMARY' AND column_name = 'case_id') THEN
   ALTER TABLE issue_records DROP PRIMARY KEY, ADD PRIMARY KEY (case_id);
  END IF;
  ALTER TABLE issue_records DROP COLUMN issue_id;
 END IF;
 IF EXISTS (SELECT 1 FROM information_schema.statistics
 WHERE table_schema = DATABASE() AND table_name = 'issue_records' AND index_name = 'idx_issue_records_case_id') THEN
  ALTER TABLE issue_records DROP INDEX idx_issue_records_case_id;
 END IF;

 -- Remove Class 8 foreign keys before removing their columns and parent tables.
 IF EXISTS (SELECT 1 FROM information_schema.table_constraints
 WHERE constraint_schema = DATABASE() AND table_name = 'orders' AND constraint_name = 'fk_orders_customer') THEN
  ALTER TABLE orders DROP FOREIGN KEY fk_orders_customer;
 END IF;
 IF EXISTS (SELECT 1 FROM information_schema.table_constraints
 WHERE constraint_schema = DATABASE() AND table_name = 'orders' AND constraint_name = 'fk_orders_product') THEN
  ALTER TABLE orders DROP FOREIGN KEY fk_orders_product;
 END IF;
 IF EXISTS (SELECT 1 FROM information_schema.table_constraints
 WHERE constraint_schema = DATABASE() AND table_name = 'orders' AND constraint_name = 'chk_orders_customer_link_source') THEN
  ALTER TABLE orders DROP CHECK chk_orders_customer_link_source;
 END IF;
 IF EXISTS (SELECT 1 FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name = 'orders' AND column_name = 'product_id') THEN
  ALTER TABLE orders DROP COLUMN product_id;
 END IF;
 IF EXISTS (SELECT 1 FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name = 'orders' AND column_name = 'customer_link_source') THEN
  ALTER TABLE orders DROP COLUMN customer_link_source;
 END IF;
 IF EXISTS (SELECT 1 FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name = 'orders' AND column_name = 'customer_id') THEN
  ALTER TABLE orders DROP COLUMN customer_id;
 END IF;
 DROP TABLE IF EXISTS products;
 DROP TABLE IF EXISTS customers;
 IF (SELECT COUNT(*) FROM issue_records) <> 25000 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Expected 25000 baseline issues after Class 8 reset';
 END IF;
 SET v_stage = 'CLASS8_MIGRATION';
 SET SESSION cte_max_recursion_depth = 15001;
-- ---------------------------------------------------------------------------
-- 0. Pre-flight visibility
-- ---------------------------------------------------------------------------
-- Expected baseline before this migration:
-- orders 20000, support_cases 25000, issue_records 25000,
-- human_reviews 10000, validation_rules 12.

SELECT 'orders' AS table_name, COUNT(*) AS row_count FROM orders
UNION ALL SELECT 'support_cases', COUNT(*) FROM support_cases
UNION ALL SELECT 'issue_records', COUNT(*) FROM issue_records
UNION ALL SELECT 'human_reviews', COUNT(*) FROM human_reviews
UNION ALL SELECT 'validation_rules', COUNT(*) FROM validation_rules;

-- ---------------------------------------------------------------------------
-- 1. Normalize customers
-- ---------------------------------------------------------------------------
-- Class 6-7 did not need a customer entity. Class 8 introduces one so the schema
-- can grow into customer-level reporting without repeating contact details on orders.

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

-- The arithmetic mapping below is synthetic, not recovered customer ownership.
-- A production backfill needs an authoritative customer identifier or approved match.
-- The explicit provenance prevents structurally complete links being read as verified identity.
-- Add the customer relationship to orders, then deterministically populate it.
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

-- ---------------------------------------------------------------------------
-- 2. Normalize products
-- ---------------------------------------------------------------------------
-- Baseline orders store the product name directly. We now give the 16 observed
-- products IDs within this fixed teaching seed. The match uses observed names,
-- not a source catalogue key. A changed sorted list need not reproduce earlier IDs.
-- orders.product is retained as the legacy observed label, frozen by this migration.
-- Current product names are resolved through product_id -> products.
-- A later catalogue rename may legitimately differ from the old observed label;
-- no continuous text synchronization is installed here.
-- UNIQUE product_name is an explicit classroom assumption, not a universal rule.

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

ALTER TABLE orders
    ADD COLUMN product_id VARCHAR(12) NULL AFTER customer_id;

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

-- ---------------------------------------------------------------------------
-- 3. Evolve issue_records from one-to-one to one-to-many
-- ---------------------------------------------------------------------------
-- At the Class 6-7 baseline, case_id is both PK and FK, which physically limits
-- a case to one issue row. Class 8 introduces issue_id as the row identity and
-- leaves case_id as a normal FK so one support case can carry multiple issues.

-- Session-local comparison evidence, not a recovery backup.
-- Captured before changing the issue grain and checked at the end of this file.
CREATE TEMPORARY TABLE class8_original_issue_evidence AS
SELECT case_id, issue_type, issue_details, reported_delivery_date,
       evidence_status, extract_generated_at
FROM issue_records;

ALTER TABLE issue_records
    ADD COLUMN issue_id VARCHAR(16) NULL FIRST;

UPDATE issue_records
SET issue_id = CONCAT('ISS-', SUBSTRING(case_id, 5));

-- The existing FK still needs an index on case_id after case_id stops being the PK.
ALTER TABLE issue_records
    ADD INDEX idx_issue_records_case_id (case_id);

ALTER TABLE issue_records
    DROP PRIMARY KEY,
    MODIFY issue_id VARCHAR(16) NOT NULL,
    ADD CONSTRAINT pk_issue_records PRIMARY KEY (issue_id);

-- Add 1,470 deterministic SYNTHETIC secondary issue rows.
-- These demonstrate cardinality; they are not newly observed customer complaints.
-- Dates and evidence states are copied for teaching and are not revalidated facts.
-- No new issue vocabulary is invented: each secondary row uses another issue type
-- that already exists in the Class 6-7 dataset.
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
        WHEN ir.issue_type = 'MISSING_ITEM'     THEN 'WRONG_ITEM'
        WHEN ir.issue_type = 'WRONG_ITEM'       THEN 'LATE_DELIVERY'
        WHEN ir.issue_type = 'DOUBLE_CHARGE'    THEN 'PAYMENT_FAILURE'
        WHEN ir.issue_type = 'PAYMENT_FAILURE'  THEN 'REFUND_DELAY'
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

-- ---------------------------------------------------------------------------
-- 4. Normalize automated routing into its own event table
-- ---------------------------------------------------------------------------
-- In the baseline, human_reviews.triggered_rule_id carries two ideas at once:
-- a review event and the automated route that preceded it. Class 8 separates the
-- route into a separate structure. The imported population is one reconstructed
-- route-evidence row per triggered review, NOT independently captured route events.
-- One real referral may have several reviews. Review time is a proxy for route time.
-- Future independently observed routes require their own source and lifecycle policy.
--
-- triggered_rule_id stays on human_reviews as a backwards-compatible snapshot.
-- New work should use case_routes when the question is about routing itself.

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

-- ---------------------------------------------------------------------------
-- 5. A normalized reusable view
-- ---------------------------------------------------------------------------
-- This case-grain view resolves current product labels through products.
-- It does not join customers, issues, reviews or routes, and is not full case evidence.
-- GENERAL cases can legitimately have no order, so LEFT JOIN preserves them.

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

-- ---------------------------------------------------------------------------
-- 6. Deliberate denormalization: refreshable reporting snapshot
-- ---------------------------------------------------------------------------
-- The snapshot duplicates product_name on purpose so a reporting consumer can
-- read one table without joining. The trade-off is freshness: unlike the view,
-- the snapshot changes only when this refresh block is run again.

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

-- UTC convention for copy creation time; source timestamps remain as supplied.
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

-- Refreshing the existing InnoDB snapshot is DML, not DDL.
-- This block is an instructor example; the migration does not schedule a refresh.
-- For a simple atomic classroom refresh, run the complete block:
-- START TRANSACTION WITH CONSISTENT SNAPSHOT;
-- SET @class8_snapshot_generated_at = UTC_TIMESTAMP();
-- DELETE FROM case_context_snapshot;
-- INSERT INTO case_context_snapshot
--     (case_id, order_id, customer_id, product_id, product_name,
--      case_type, review_status, received_at, snapshot_generated_at)
-- SELECT case_id, order_id, customer_id, product_id, product_name,
--        case_type, review_status, received_at, @class8_snapshot_generated_at
-- FROM vw_case_context;
-- COMMIT;
-- On any error before COMMIT, ROLLBACK. Do not substitute TRUNCATE (DDL).
-- Production refresh scheduling, concurrent writers and publication need a policy.

-- ---------------------------------------------------------------------------
-- 7. End-of-migration checks
-- ---------------------------------------------------------------------------

SELECT 'customers' AS object_name, COUNT(*) AS actual_rows, 15000 AS expected_rows
FROM customers
UNION ALL
SELECT 'products', COUNT(*), 16 FROM products
UNION ALL
SELECT 'issue_records', COUNT(*), 26470 FROM issue_records
UNION ALL
SELECT 'case_routes imported evidence', COUNT(*), 3564 FROM case_routes
UNION ALL
SELECT 'case_context_snapshot', COUNT(*), 25000 FROM case_context_snapshot;

-- Immediately after this migration, current names and legacy labels align.
-- Expected: 0 at initialization only, not after a legitimate catalogue rename.
SELECT COUNT(*) AS initial_product_label_mismatches
FROM orders AS o
JOIN products AS p
    ON p.product_id = o.product_id
WHERE o.product <> p.product_name;

-- Every customer and product link should resolve. Expected: 0.
SELECT COUNT(*) AS orphan_order_dimensions
FROM orders AS o
LEFT JOIN customers AS c
    ON c.customer_id = o.customer_id
LEFT JOIN products AS p
    ON p.product_id = o.product_id
WHERE c.customer_id IS NULL
   OR p.product_id IS NULL;

-- Exactly 1,470 cases now demonstrate a second issue row.
SELECT COUNT(*) AS cases_with_multiple_issues
FROM (
    SELECT case_id
    FROM issue_records
    GROUP BY case_id
    HAVING COUNT(*) > 1
) AS multi_issue_cases;

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

-- View and snapshot should cover the same support-case grain. Expected: 25000 / 25000.
SELECT
    (SELECT COUNT(*) FROM vw_case_context) AS view_rows,
    (SELECT COUNT(*) FROM case_context_snapshot) AS snapshot_rows;


-- Verify every original issue field was preserved, not only the row count.
-- Expected: 0. Secondary generated issues are excluded by the original identity.
SELECT COUNT(*) AS original_issue_preservation_failures
FROM class8_original_issue_evidence AS b
LEFT JOIN issue_records AS ir
  ON ir.issue_id = CONCAT('ISS-', SUBSTRING(b.case_id, 5))
WHERE ir.issue_id IS NULL
   OR NOT (
       CAST(ir.case_id AS BINARY) <=> CAST(b.case_id AS BINARY)
       AND CAST(ir.issue_type AS BINARY) <=> CAST(b.issue_type AS BINARY)
       AND CAST(ir.issue_details AS BINARY) <=> CAST(b.issue_details AS BINARY)
       AND ir.reported_delivery_date <=> b.reported_delivery_date
       AND CAST(ir.evidence_status AS BINARY) <=> CAST(b.evidence_status AS BINARY)
       AND ir.extract_generated_at <=> b.extract_generated_at
   );

DROP TEMPORARY TABLE class8_original_issue_evidence;


 SET v_stage = 'VERIFY';
 IF (SELECT COUNT(*) FROM customers) <> 15000
 OR (SELECT COUNT(*) FROM products) <> 16
 OR (SELECT COUNT(*) FROM issue_records) <> 26470
 OR (SELECT COUNT(*) FROM case_routes) <> 3564
 OR (SELECT COUNT(*) FROM case_context_snapshot) <> 25000 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Class 8 final row counts differ from expected';
 END IF;
 SET SESSION sql_safe_updates = v_safe;
 SET SESSION cte_max_recursion_depth = v_depth;
 SET @class8_run_status = 'SUCCESS';
 SELECT @class8_run_status AS class8_status;
END$$
DELIMITER ;
CALL class8_only_reset_and_run();
DROP PROCEDURE IF EXISTS class8_only_reset_and_run;
