-- Meridian Retail FDE Programme
-- Class 8 refined model-evolution verification
-- Structural and source-provenance checks; no inference of authentic customer identity.
-- All checks labelled Expected: 0 must return zero on the initialized teaching seed.
-- Fixture counts and provenance expectations must change when real new data is added.
-- This file is an initialization acceptance check, not an unchanged production monitor.
-- Run after:
--   00_base_schema.sql
--   01_seed_base_data.sql
--   02_verify_base_dataset.sql
--   03_class8_model_evolution_refined.sql

USE meridian_retail;

-- 1. Expected object counts.
SELECT 'customers' AS object_name, COUNT(*) AS actual_rows, 15000 AS expected_rows
FROM customers
UNION ALL
SELECT 'products', COUNT(*), 16 FROM products
UNION ALL
SELECT 'orders', COUNT(*), 20000 FROM orders
UNION ALL
SELECT 'support_cases', COUNT(*), 25000 FROM support_cases
UNION ALL
SELECT 'issue_records', COUNT(*), 26470 FROM issue_records
UNION ALL
SELECT 'human_reviews', COUNT(*), 10000 FROM human_reviews
UNION ALL
SELECT 'validation_rules', COUNT(*), 12 FROM validation_rules
UNION ALL
SELECT 'case_routes', COUNT(*), 3564 FROM case_routes
UNION ALL
SELECT 'case_context_snapshot', COUNT(*), 25000 FROM case_context_snapshot;

-- 2. Customer/product foreign keys resolve. Expected: 0.
SELECT COUNT(*) AS orphan_order_dimensions
FROM orders AS o
LEFT JOIN customers AS c
    ON c.customer_id = o.customer_id
LEFT JOIN products AS p
    ON p.product_id = o.product_id
WHERE c.customer_id IS NULL
   OR p.product_id IS NULL;

-- 3. Initial legacy label alignment. Expected: 0 immediately after migration.
-- orders.product is retained observed text; later catalogue renames may differ legitimately.
SELECT COUNT(*) AS initial_product_label_mismatches
FROM orders AS o
JOIN products AS p
    ON p.product_id = o.product_id
WHERE o.product <> p.product_name;

-- 4. issue_records is now one-to-many by case_id.
-- Expected: 25000 distinct cases, 26470 rows, 1470 extra issue rows.
SELECT
    COUNT(*) AS issue_rows,
    COUNT(DISTINCT case_id) AS distinct_issue_cases,
    COUNT(*) - COUNT(DISTINCT case_id) AS additional_issue_rows
FROM issue_records;

-- Expected: 1470.
SELECT COUNT(*) AS cases_with_multiple_issues
FROM (
    SELECT case_id
    FROM issue_records
    GROUP BY case_id
    HAVING COUNT(*) > 1
) AS multi_issue_cases;

-- 5. Every issue row still resolves to a support case. Expected: 0.
SELECT COUNT(*) AS orphan_issue_records
FROM issue_records AS ir
LEFT JOIN support_cases AS sc
    ON sc.case_id = ir.case_id
WHERE sc.case_id IS NULL;

-- 6. Imported route evidence contains exactly the legacy non-null trigger population.
-- This is one row per triggered review, not independently observed route history.
-- Expected: 3564 / 3564.
SELECT
    (SELECT COUNT(*) FROM case_routes WHERE event_source = 'LEGACY_REVIEW') AS imported_route_rows,
    (SELECT COUNT(*) FROM human_reviews WHERE triggered_rule_id IS NOT NULL) AS legacy_triggered_reviews;

-- Expected: 0.
SELECT COUNT(*) AS route_migration_mismatches
FROM human_reviews AS hr
LEFT JOIN case_routes AS cr
    ON cr.source_review_id = hr.review_id
   AND cr.event_source = 'LEGACY_REVIEW'
WHERE hr.triggered_rule_id IS NOT NULL
  AND (
      cr.route_id IS NULL
      OR cr.rule_id <> hr.triggered_rule_id
      OR cr.case_id <> hr.case_id
      OR cr.timestamp_basis <> 'REVIEW_TIME_PROXY'
      OR cr.routed_at <> hr.reviewed_at
  );

-- 7. Every route resolves to a case/rule and any supplied source review.
-- An imported route requires its source; an observed future route may have none.
-- Expected: 0.
SELECT COUNT(*) AS orphan_case_routes
FROM case_routes AS cr
LEFT JOIN support_cases AS sc
    ON sc.case_id = cr.case_id
LEFT JOIN validation_rules AS vr
    ON vr.rule_id = cr.rule_id
LEFT JOIN human_reviews AS hr
    ON hr.review_id = cr.source_review_id
WHERE sc.case_id IS NULL
   OR vr.rule_id IS NULL
   OR (cr.source_review_id IS NOT NULL AND hr.review_id IS NULL)
   OR (cr.event_source = 'LEGACY_REVIEW' AND cr.source_review_id IS NULL);

-- 8. Normalized view preserves all support cases. Expected: 25000.
SELECT COUNT(*) AS normalized_view_rows
FROM vw_case_context;

-- General cases without orders survive the LEFT JOIN with NULL dimensions.
-- Expected: 2499 on this fixed seed.
SELECT COUNT(*) AS cases_without_order_in_view
FROM vw_case_context
WHERE order_id IS NULL
  AND customer_id IS NULL
  AND product_id IS NULL;

-- 9. Snapshot starts aligned with the view. Expected: 25000 / 25000 and 0 mismatches.
SELECT
    (SELECT COUNT(*) FROM vw_case_context) AS view_rows,
    (SELECT COUNT(*) FROM case_context_snapshot) AS snapshot_rows;

SELECT COUNT(*) AS snapshot_content_mismatches
FROM vw_case_context AS v
JOIN case_context_snapshot AS s
    ON s.case_id = v.case_id
WHERE NOT (
    s.order_id <=> v.order_id
    AND s.customer_id <=> v.customer_id
    AND s.product_id <=> v.product_id
    AND s.product_name <=> v.product_name
    AND s.case_type = v.case_type
    AND s.review_status = v.review_status
    AND s.received_at = v.received_at
);

-- 10. Class 5 anchors still exist and remain easy to inspect.
SELECT
    sc.case_id,
    sc.order_id,
    o.customer_id,
    o.product_id,
    p.product_name,
    sc.case_type,
    sc.review_status
FROM support_cases AS sc
LEFT JOIN orders AS o
    ON o.order_id = sc.order_id
LEFT JOIN products AS p
    ON p.product_id = o.product_id
WHERE sc.case_id IN ('MCS-501', 'MCS-502')
ORDER BY sc.case_id;

-- 11. Show one case that now has multiple issue rows for the Class 8 relationship demo.
SELECT
    ir.case_id,
    ir.issue_id,
    ir.issue_type,
    ir.evidence_status
FROM issue_records AS ir
WHERE ir.case_id = (
    SELECT case_id
    FROM issue_records
    GROUP BY case_id
    HAVING COUNT(*) > 1
    ORDER BY case_id
    LIMIT 1
)
ORDER BY ir.issue_id;


-- 12. Explicit synthetic provenance for this teaching backfill. Expected: 0 / 0.
SELECT COUNT(*) AS customer_provenance_failures
FROM customers WHERE identity_source <> 'SYNTHETIC_TEACHING';

SELECT COUNT(*) AS order_customer_link_provenance_failures
FROM orders WHERE customer_link_source <> 'SYNTHETIC_TEACHING';

-- A foreign key cannot prove this synthetic match represents authentic ownership.
-- Production identity verification must compare with an approved external source.

-- 13. No extra or wrongly attributed imported route evidence. Expected: 0.
SELECT COUNT(*) AS extra_or_mismatched_imported_routes
FROM case_routes AS cr
LEFT JOIN human_reviews AS hr ON hr.review_id = cr.source_review_id
WHERE cr.event_source = 'LEGACY_REVIEW'
  AND (hr.review_id IS NULL
       OR hr.triggered_rule_id IS NULL
       OR NOT (cr.case_id <=> hr.case_id)
       OR NOT (cr.rule_id <=> hr.triggered_rule_id)
       OR cr.timestamp_basis <> 'REVIEW_TIME_PROXY'
       OR NOT (cr.routed_at <=> hr.reviewed_at));

-- Any supplied source review must belong to the same case. Expected: 0.
SELECT COUNT(*) AS route_review_case_mismatches
FROM case_routes AS cr
JOIN human_reviews AS hr ON hr.review_id = cr.source_review_id
WHERE cr.case_id <> hr.case_id;

-- 14. Same identifiers as well as same counts in view and snapshot. Expected: 0 each.
SELECT COUNT(*) AS cases_missing_from_view
FROM support_cases AS sc
LEFT JOIN vw_case_context AS v ON v.case_id = sc.case_id
WHERE v.case_id IS NULL;

SELECT COUNT(*) AS view_cases_missing_from_support
FROM vw_case_context AS v
LEFT JOIN support_cases AS sc ON sc.case_id = v.case_id
WHERE sc.case_id IS NULL;

SELECT COUNT(*) AS duplicate_case_ids_in_view
FROM (
    SELECT case_id FROM vw_case_context
    GROUP BY case_id HAVING COUNT(*) <> 1
) AS duplicate_cases;

SELECT COUNT(*) AS missing_snapshot_cases
FROM vw_case_context AS v
LEFT JOIN case_context_snapshot AS s ON s.case_id = v.case_id
WHERE s.case_id IS NULL;

SELECT COUNT(*) AS extra_snapshot_cases
FROM case_context_snapshot AS s
LEFT JOIN vw_case_context AS v ON v.case_id = s.case_id
WHERE v.case_id IS NULL;

-- 15. Original issue identity mapping remains complete. Expected: 0.
-- Full original-field comparison is emitted by the migration while its temporary
-- pre-change evidence exists. This independent file checks identity and anchors.
SELECT COUNT(*) AS cases_missing_original_issue
FROM support_cases AS sc
LEFT JOIN issue_records AS ir
  ON ir.case_id = sc.case_id
 AND ir.issue_id = CONCAT('ISS-', SUBSTRING(sc.case_id, 5))
WHERE ir.issue_id IS NULL;

-- 16. Snapshot creation time is recorded in UTC, not a hard-coded teaching date.
-- Expected: one non-null timestamp, identical on all rows in the initial refresh.
SELECT COUNT(*) AS snapshot_rows,
       COUNT(DISTINCT snapshot_generated_at) AS distinct_refresh_times,
       MIN(snapshot_generated_at) AS first_refresh_utc,
       MAX(snapshot_generated_at) AS last_refresh_utc
FROM case_context_snapshot;

-- 17. All route rows in this initialized fixture are explicitly reconstructed.
-- Expected: LEGACY_REVIEW | REVIEW_TIME_PROXY | 3564.
SELECT event_source, timestamp_basis, COUNT(*) AS route_rows
FROM case_routes
GROUP BY event_source, timestamp_basis;


-- 18. Check the deterministic customer assignment, not merely parent existence.
-- Expected: 0. This proves the teaching formula was followed, not real ownership.
SELECT COUNT(*) AS synthetic_customer_mapping_mismatches
FROM orders
WHERE customer_link_source = 'SYNTHETIC_TEACHING'
  AND customer_id <> CONCAT(
      'CUS-',
      LPAD(1 + MOD(
          CAST(SUBSTRING_INDEX(order_id, '-', -1) AS UNSIGNED) - 1,
          15000), 6, '0')
  );
