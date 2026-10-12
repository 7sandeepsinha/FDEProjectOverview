-- =============================================================================
-- 00B  FINISH THE CLASS 8 MODEL: the delta before Class 10
-- Run the WHOLE file once, in one connection, top to bottom.
--
-- Starting point (confirm with 00A_where_we_are_now.sql):
--   Class 8 already changed issue_records so that issue_id is the primary key
--   (one case can hold many issues). The rest of the Class 8 model was not
--   built yet. This file builds only what is missing:
--
--   Step 0  guards: stop before any change if the starting point differs
--   Step 1  remove the hand-made demo issue row(s) ISS-DEMO-...
--   Step 2  customers + orders.customer_id
--   Step 3  products  + orders.product_id
--   Step 4  1,470 synthetic second issues (one case -> many issues)
--   Step 5  case_routes: routing events, separated from human reviews
--   Step 6  vw_case_context: normalized view, always current
--   Step 7  case_context_snapshot: stored reporting copy, refreshed on demand
--   Step 8  checks: every actual value should equal its expected value
--
-- It does NOT drop the database. It does not change any support_cases,
-- human_reviews or validation_rules row. Steps 2-7 are the same SQL as
-- CLASS 8 SCRIPTS/03_class8_model_evolution_classroom.sql.
--
-- Safety
--   * If a Step 0 guard fails you will see:
--       Check constraint 'delta_guard_must_pass' is violated.
--     Nothing has been changed. Run 00A and follow its next_step.
--   * CREATE/ALTER statements commit immediately and cannot be rolled back.
--     If anything fails after Step 1, do not rerun this file. Rebuild with
--     CLASS 8 SCRIPTS 00 -> 01 -> 02 -> 03_class8_model_evolution_classroom.
--   * DBeaver: run as a script (Alt+X) and stop on the first error.
--     Workbench: enable "Stop Script Execution On Errors".
-- =============================================================================

USE meridian_retail;

-- Session settings this file changes; Step 8 restores them.
SET @delta_saved_safe_updates = @@SESSION.sql_safe_updates;
SET @delta_saved_cte_depth = @@SESSION.cte_max_recursion_depth;

-- ---------------------------------------------------------------------------
-- Step 0. Guards: confirm the starting point before changing anything
-- ---------------------------------------------------------------------------

DROP TEMPORARY TABLE IF EXISTS delta_guard;
CREATE TEMPORARY TABLE delta_guard (
    guard_name VARCHAR(60) NOT NULL,
    ok         INT         NOT NULL,
    CONSTRAINT delta_guard_must_pass CHECK (ok = 1)
) ENGINE = InnoDB;

-- Guard A: the rows from earlier classes are all present.
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

-- Session-local comparison evidence, checked in Step 8. Not a backup.
DROP TEMPORARY TABLE IF EXISTS delta_original_issue_evidence;
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

-- ---------------------------------------------------------------------------
-- Step 2. Normalize customers
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
-- Step 3. Normalize products
-- ---------------------------------------------------------------------------
-- Baseline orders store the product name directly. We give the 16 observed
-- products IDs within this fixed teaching seed. orders.product is retained as
-- the legacy observed label; current names resolve through product_id -> products.
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
-- Step 4. Add 1,470 synthetic second issues
-- ---------------------------------------------------------------------------
-- issue_id is already the row identity (done in Class 8), so a case can now
-- carry more than one issue. These rows demonstrate that cardinality; they are
-- not newly observed customer complaints. Each uses an issue type that already
-- exists in the Class 6-7 dataset.

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

-- ---------------------------------------------------------------------------
-- Step 5. Normalize automated routing into its own event table
-- ---------------------------------------------------------------------------
-- human_reviews.triggered_rule_id carries two ideas at once: a review event and
-- the automated route that preceded it. case_routes separates the route. The
-- imported rows are reconstructed route evidence, one per triggered review;
-- review time is a proxy for route time. triggered_rule_id stays on
-- human_reviews for backwards compatibility.

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
-- Step 6. A normalized reusable view
-- ---------------------------------------------------------------------------
-- Case-grain view: one row per support case, with its order's customer and
-- current product name. GENERAL cases can have no order, so LEFT JOIN keeps them.
-- (The earlier hand-made support_case_details view is left unchanged.)

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
-- Step 7. Deliberate denormalization: refreshable reporting snapshot
-- ---------------------------------------------------------------------------
-- The snapshot copies the view's rows into a real table so a report can read
-- one table without joins. Trade-off: unlike the view, it changes only when it
-- is refreshed. Class 10 builds its 500,000-row practice table from it.

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

-- ---------------------------------------------------------------------------
-- Step 8. Checks
-- ---------------------------------------------------------------------------

-- Every actual_rows should equal expected_rows.
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

-- NEXT: run 00A_where_we_are_now.sql again. Every status should be OK and
-- next_step should say "Ready for Class 10". Then 00_class10_preflight.sql
-- and 01_class10_setup.sql, as the Class 10 script directs.
