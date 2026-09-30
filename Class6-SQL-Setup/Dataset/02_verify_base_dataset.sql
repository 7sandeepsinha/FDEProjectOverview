-- Meridian Retail baseline verification
-- Run after 00_base_schema.sql and 01_seed_base_data.sql.

USE meridian_retail;

-- 1. Expected row counts.
SELECT 'orders' AS table_name, COUNT(*) AS actual_rows, 20000 AS expected_rows
FROM orders
UNION ALL
SELECT 'support_cases', COUNT(*), 25000 FROM support_cases
UNION ALL
SELECT 'issue_records', COUNT(*), 25000 FROM issue_records
UNION ALL
SELECT 'human_reviews', COUNT(*), 10000 FROM human_reviews
UNION ALL
SELECT 'validation_rules', COUNT(*), 12 FROM validation_rules;

-- 2. Every support-case order link must resolve. Expected: 0.
SELECT COUNT(*) AS orphan_case_order_links
FROM support_cases AS sc
LEFT JOIN orders AS o
    ON o.order_id = sc.order_id
WHERE sc.order_id IS NOT NULL
  AND o.order_id IS NULL;

-- 3. Every issue must resolve to one support case. Expected: 0.
SELECT COUNT(*) AS orphan_issue_records
FROM issue_records AS ir
LEFT JOIN support_cases AS sc
    ON sc.case_id = ir.case_id
WHERE sc.case_id IS NULL;

-- 4. Every review must resolve to a case and any supplied rule. Expected: 0.
SELECT COUNT(*) AS orphan_human_reviews
FROM human_reviews AS hr
LEFT JOIN support_cases AS sc
    ON sc.case_id = hr.case_id
LEFT JOIN validation_rules AS vr
    ON vr.rule_id = hr.triggered_rule_id
WHERE sc.case_id IS NULL
   OR (hr.triggered_rule_id IS NOT NULL AND vr.rule_id IS NULL);

-- 5. RETURN and DAMAGE cases must have an order. Expected: 0.
SELECT COUNT(*) AS purchase_cases_missing_order
FROM support_cases
WHERE case_type IN ('RETURN', 'DAMAGE')
  AND order_id IS NULL;

-- 6. Baseline grain checks.
SELECT
    COUNT(*) AS issue_rows,
    COUNT(DISTINCT case_id) AS distinct_issue_cases
FROM issue_records;

SELECT
    COUNT(*) AS review_events,
    COUNT(DISTINCT case_id) AS reviewed_cases,
    COUNT(*) - COUNT(DISTINCT case_id) AS additional_review_events
FROM human_reviews;

-- 7. Confirm one-to-many behaviour exists for joins.
SELECT order_id, COUNT(*) AS case_count
FROM support_cases
WHERE order_id IS NOT NULL
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY case_count DESC, order_id
LIMIT 10;

SELECT case_id, COUNT(*) AS review_count
FROM human_reviews
GROUP BY case_id
HAVING COUNT(*) > 1
ORDER BY review_count DESC, case_id
LIMIT 10;

-- 8. Confirm legitimate NULLs and valid edge conditions exist.
SELECT
    SUM(order_id IS NULL) AS cases_without_order,
    SUM(review_status = 'PENDING') AS pending_cases,
    SUM(review_status = 'REJECTED') AS rejected_cases
FROM support_cases;

SELECT
    SUM(delivery_date IS NULL) AS orders_without_delivery_date,
    SUM(payment_status = 'FAILED') AS failed_payments,
    SUM(payment_status = 'REFUNDED') AS refunded_orders
FROM orders;

SELECT evidence_status, COUNT(*) AS issue_count
FROM issue_records
GROUP BY evidence_status
ORDER BY issue_count DESC, evidence_status;

-- 9. Confirm the deliberate cross-source disagreements are visible.
SELECT COUNT(*) AS conflicting_delivery_dates
FROM issue_records AS ir
JOIN support_cases AS sc
    ON sc.case_id = ir.case_id
JOIN orders AS o
    ON o.order_id = sc.order_id
WHERE ir.reported_delivery_date IS NOT NULL
  AND o.delivery_date IS NOT NULL
  AND ir.reported_delivery_date <> o.delivery_date;

-- 10. Confirm Class 5 anchor cases remain visible.
SELECT
    sc.case_id,
    sc.order_id,
    sc.case_type,
    sc.review_status,
    ir.issue_type,
    ir.evidence_status
FROM support_cases AS sc
JOIN issue_records AS ir
    ON ir.case_id = sc.case_id
WHERE sc.case_id IN ('MCS-501', 'MCS-502')
ORDER BY sc.case_id;

SELECT
    hr.review_id,
    hr.case_id,
    hr.triggered_rule_id,
    hr.decision,
    hr.decision_reason
FROM human_reviews AS hr
WHERE hr.case_id = 'MCS-502';

-- 11. Class 5 handoff question, now answerable from the five-table baseline.
SELECT
    ir.issue_type,
    hr.triggered_rule_id,
    vr.reason AS rule_reason,
    COUNT(DISTINCT hr.case_id) AS reviewed_cases
FROM human_reviews AS hr
JOIN issue_records AS ir
    ON ir.case_id = hr.case_id
JOIN validation_rules AS vr
    ON vr.rule_id = hr.triggered_rule_id
GROUP BY ir.issue_type, hr.triggered_rule_id, vr.reason
ORDER BY reviewed_cases DESC, ir.issue_type, hr.triggered_rule_id;

