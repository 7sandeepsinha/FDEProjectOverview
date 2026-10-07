-- Class 8 live queries
-- RUN ONE NUMBERED BLOCK AT A TIME. Do not execute this entire file.
-- Block 02 intentionally errors. Run the complete migration between 02 and 03.
-- Blocks 04 and 12 contain complete reversible demonstrations.
-- If a demo fails, issue ROLLBACK before moving on.

-- BLOCK 01 | CARD 1 | Baseline
USE meridian_retail;
SELECT COUNT(*) AS baseline_issues FROM issue_records;

-- BLOCK 02 | CARD 1 | Expected duplicate key error before migration
INSERT INTO issue_records
    (case_id, issue_type, issue_details, reported_delivery_date,
     evidence_status, extract_generated_at)
VALUES
    ('MCS-502', 'MISSING_ITEM',
     'Hypothetical second issue for the classroom demonstration.',
     NULL, 'PENDING_PROOF', '2026-09-18 11:40:00');

-- BLOCK 03 | CARD 6 | After complete migration
SELECT issue_id, case_id, issue_type, evidence_status
FROM issue_records
WHERE case_id = 'MCS-000001'
ORDER BY issue_id;

SELECT COUNT(*) AS issue_rows,
       COUNT(DISTINCT case_id) AS cases_with_issues
FROM issue_records;

-- BLOCK 04 | CARD 6 | Reversible MCS502 issue demonstration
START TRANSACTION;
INSERT INTO issue_records
    (issue_id, case_id, issue_type, issue_details,
     reported_delivery_date, evidence_status, extract_generated_at)
VALUES
    ('ISS-DEMO-502', 'MCS-502', 'MISSING_ITEM',
     'Hypothetical second issue for the classroom demonstration.',
     NULL, 'PENDING_PROOF', '2026-09-18 11:40:00');
SELECT issue_id, case_id, issue_type
FROM issue_records WHERE case_id = 'MCS-502'
ORDER BY issue_id;
ROLLBACK;
SELECT COUNT(*) AS issues_after_demo FROM issue_records;

-- BLOCK 05 | CARD 7 | Wrong and actual review totals
SELECT ir.issue_id, hr.review_id, hr.handling_minutes
FROM issue_records AS ir
JOIN human_reviews AS hr ON hr.case_id = ir.case_id
WHERE ir.case_id = 'MCS-000001'
ORDER BY ir.issue_id, hr.review_id;

SELECT SUM(hr.handling_minutes) AS joined_handling_minutes
FROM issue_records AS ir
JOIN human_reviews AS hr ON hr.case_id = ir.case_id
WHERE ir.case_id = 'MCS-000001';

SELECT SUM(handling_minutes) AS actual_review_minutes
FROM human_reviews WHERE case_id = 'MCS-000001';

-- BLOCK 06 | CARD 8 | Repaired CTE report
WITH issue_summary AS (
    SELECT case_id, COUNT(*) AS issue_count
    FROM issue_records
    GROUP BY case_id
), review_summary AS (
    SELECT case_id, COUNT(*) AS review_count,
           SUM(handling_minutes) AS total_handling_minutes
    FROM human_reviews
    GROUP BY case_id
)
SELECT sc.case_id,
       COALESCE(i.issue_count, 0) AS issue_count,
       COALESCE(r.review_count, 0) AS review_count,
       r.total_handling_minutes
FROM support_cases AS sc
LEFT JOIN issue_summary AS i ON i.case_id = sc.case_id
LEFT JOIN review_summary AS r ON r.case_id = sc.case_id
WHERE sc.case_id = 'MCS-000001';

-- BLOCK 07 | CARD 9 | SUM DISTINCT equal value trap
WITH review_example AS (
    SELECT 'R1' AS review_id, 30 AS handling_minutes
    UNION ALL
    SELECT 'R2', 30
)
SELECT COUNT(*) AS review_events,
       SUM(handling_minutes) AS actual_minutes,
       SUM(DISTINCT handling_minutes) AS distinct_value_minutes
FROM review_example;

-- BLOCK 08 | CARD 10 | Product relationship
SELECT o.order_id, o.product AS legacy_product_text,
       o.product_id, p.product_name AS current_product_name
FROM orders AS o
JOIN products AS p ON p.product_id = o.product_id
WHERE o.order_id = 'MR-502';

-- BLOCK 09 | CARD 11 | Customer provenance
SELECT customer_id, email, identity_source
FROM customers ORDER BY customer_id LIMIT 3;

SELECT order_id, customer_id, customer_link_source
FROM orders WHERE order_id IN ('MR-501', 'MR-502')
ORDER BY order_id;

-- BLOCK 10 | CARD 11 | Route provenance
SELECT cr.case_id, cr.rule_id, cr.event_source,
       cr.timestamp_basis, cr.routed_at, hr.reviewed_at
FROM case_routes AS cr
JOIN human_reviews AS hr ON hr.review_id = cr.source_review_id
WHERE cr.case_id = 'MCS-502';

-- BLOCK 11 | CARD 12 | View and snapshot
SELECT COUNT(*) AS case_rows,
       SUM(order_id IS NULL) AS cases_without_orders
FROM vw_case_context;

SELECT case_id, product_name, snapshot_generated_at
FROM case_context_snapshot WHERE case_id = 'MCS-502';

-- BLOCK 12 | CARD 12 | Reversible product rename
SET @class8_demo_product_id = (
    SELECT product_id FROM orders WHERE order_id = 'MR-502'
);
START TRANSACTION;
UPDATE products
SET product_name = 'USB-C Multi-Port Hub Classroom Demo'
WHERE product_id = @class8_demo_product_id;
SELECT v.case_id, v.product_name AS view_name,
       s.product_name AS snapshot_name
FROM vw_case_context AS v
JOIN case_context_snapshot AS s ON s.case_id = v.case_id
WHERE v.case_id = 'MCS-502';
ROLLBACK;
SELECT product_name AS restored_product_name
FROM products WHERE product_id = @class8_demo_product_id;
