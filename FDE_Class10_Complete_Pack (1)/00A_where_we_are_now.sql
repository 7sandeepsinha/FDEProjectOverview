-- =============================================================================
-- 00A  WHERE IS OUR MERIDIAN DATABASE RIGHT NOW?                  READ ONLY
-- Changes nothing. Safe to run top to bottom, as many times as you like.
--
-- Run it at the start of Class 10 to see where we stand, and again after
-- 00B_finish_class8_delta.sql to see every checklist line become OK.
--
-- Result 1: the tables and views in meridian_retail today
-- Result 2: checklist of what Class 10 needs versus what we have
-- Result 3: next_step tells you which file to run next
-- =============================================================================

USE meridian_retail;

-- Result 1: what is in the database today
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = DATABASE()
ORDER BY table_type, table_name;

-- Result 2: checklist. Every status should be OK before 00_class10_preflight.sql.
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

-- Result 3: which file to run next
SELECT CASE
    WHEN core_ok = 0
        THEN 'Earlier-class rows are missing or changed. Rebuild: CLASS 8 SCRIPTS 00 -> 01 -> 02 -> 03_class8_model_evolution_classroom -> 03_verify.'
    WHEN case_columns <> 7
        THEN 'support_cases has extra columns (Class 9 homework?). Keep that copy; use a separate post-Class-8 copy for Class 10.'
    WHEN class8_objects = 7 AND issue_pk = 'issue_id' AND issue_rows = 26470 AND class10_fixture = 1
        THEN 'Class 10 setup already done. Follow the script''s IF ALREADY SET UP cue.'
    WHEN class8_objects = 7 AND issue_pk = 'issue_id' AND issue_rows = 26470
        THEN 'Ready for Class 10. Run 00_class10_preflight.sql, then 01_class10_setup.sql.'
    WHEN class8_objects = 0 AND issue_pk = 'issue_id'
        THEN 'Class 8 finished only the issue_records step. Run 00B_finish_class8_delta.sql.'
    WHEN class8_objects = 0 AND issue_pk = 'case_id' AND issue_rows = 25000
        THEN 'Class 8 model not started. Run CLASS 8 SCRIPTS/03_class8_model_evolution_classroom.sql.'
    ELSE 'Unrecognised state. Rebuild: CLASS 8 SCRIPTS 00 -> 01 -> 02 -> 03_class8_model_evolution_classroom -> 03_verify.'
END AS next_step
FROM (
    SELECT
        IF((SELECT COUNT(*) FROM orders) = 20000
           AND (SELECT COUNT(*) FROM support_cases WHERE case_id NOT LIKE 'MCS-C10-%') = 25000
           AND (SELECT COUNT(*) FROM human_reviews WHERE review_id NOT LIKE 'MHR-C10-%') = 10000
           AND (SELECT COUNT(*) FROM validation_rules) = 12, 1, 0) AS core_ok,
        (SELECT COUNT(*) FROM information_schema.columns
         WHERE table_schema = DATABASE() AND table_name = 'support_cases') AS case_columns,
        (SELECT COALESCE(GROUP_CONCAT(column_name ORDER BY ordinal_position), '(none)')
         FROM information_schema.key_column_usage
         WHERE table_schema = DATABASE() AND table_name = 'issue_records'
           AND constraint_name = 'PRIMARY') AS issue_pk,
        (SELECT COUNT(*) FROM issue_records) AS issue_rows,
        (SELECT COUNT(*) FROM information_schema.tables
         WHERE table_schema = DATABASE()
           AND table_name IN ('customers', 'products', 'case_routes',
                              'vw_case_context', 'case_context_snapshot'))
        + (SELECT COUNT(*) FROM information_schema.columns
           WHERE table_schema = DATABASE() AND table_name = 'orders'
             AND column_name IN ('customer_id', 'product_id')) AS class8_objects,
        (SELECT COUNT(*) FROM information_schema.tables
         WHERE table_schema = DATABASE()
           AND table_name = 'class10_case_search') AS class10_fixture
) AS state;
