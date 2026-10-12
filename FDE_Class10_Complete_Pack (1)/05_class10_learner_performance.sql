-- PERFORMANCE ONLY. Named blocks; NEVER run the whole file.
-- Each learner needs their OWN disposable Meridian copy for index creation.
-- Shared server: instructor creates indexes ONCE; learners observe/read only.
-- CREATE INDEX commits implicitly. No open business transaction during this phase.
USE meridian_retail;

-- BLOCK P00 | Prepare and establish table size / only PRIMARY at baseline
ROLLBACK;
SET autocommit=1;
SELECT COUNT(*) AS observation_rows,COUNT(DISTINCT source_case_id) AS source_cases
FROM class10_case_search;
SHOW INDEX FROM class10_case_search;

-- Fixed supplied seed: Q1 count=60; Q2 rows=12; date query count=3203.
-- A changed source snapshot can change these fixture values.

-- BLOCK P01 | Q1 baseline: run three times; record comparable Duration values
SELECT COUNT(*) AS matching_observations FROM class10_case_search
WHERE customer_id='CUS-000001';

-- BLOCK P02 | Q1 baseline plan; rows is an estimate, not a timing
EXPLAIN FORMAT=TRADITIONAL SELECT COUNT(*) AS matching_observations FROM class10_case_search
WHERE customer_id='CUS-000001';

-- BLOCK P03 | Create ONE single-column index; run once on this copy
CREATE INDEX idx_c10_customer ON class10_case_search(customer_id);

-- BLOCK P04 | Same Q1 after index: same result, compare plan and three runs
EXPLAIN FORMAT=TRADITIONAL SELECT COUNT(*) AS matching_observations FROM class10_case_search
WHERE customer_id='CUS-000001';
SELECT COUNT(*) AS matching_observations FROM class10_case_search
WHERE customer_id='CUS-000001';

-- BLOCK P05 | New Q2 workload with only customer index; record ordered IDs
EXPLAIN FORMAT=TRADITIONAL SELECT observation_id,source_case_id,received_at,context_note
FROM class10_case_search
WHERE customer_id='CUS-000001' AND review_status='PENDING'
  AND received_at >= '2026-09-01' AND received_at < '2026-10-01'
ORDER BY received_at,observation_id;
SELECT observation_id,source_case_id,received_at,context_note
FROM class10_case_search
WHERE customer_id='CUS-000001' AND review_status='PENDING'
  AND received_at >= '2026-09-01' AND received_at < '2026-10-01'
ORDER BY received_at,observation_id;

-- BLOCK P06 | Test composite candidate; run once
CREATE INDEX idx_c10_customer_status_date
ON class10_case_search(customer_id,review_status,received_at);

-- BLOCK P07 | Same Q2; compare chosen key, estimated work and exact ordered IDs
EXPLAIN FORMAT=TRADITIONAL SELECT observation_id,source_case_id,received_at,context_note
FROM class10_case_search
WHERE customer_id='CUS-000001' AND review_status='PENDING'
  AND received_at >= '2026-09-01' AND received_at < '2026-10-01'
ORDER BY received_at,observation_id;
SELECT observation_id,source_case_id,received_at,context_note
FROM class10_case_search
WHERE customer_id='CUS-000001' AND review_status='PENDING'
  AND received_at >= '2026-09-01' AND received_at < '2026-10-01'
ORDER BY received_at,observation_id;

-- BLOCK P08 | Actual execution, supplied read-only Q2 ONLY
-- If server is 8.0.32+ and explain_format=JSON, reset session explain_format
-- to TRADITIONAL before using this block; do so before class, not mid-demo.
EXPLAIN ANALYZE SELECT observation_id,source_case_id,received_at,context_note
FROM class10_case_search
WHERE customer_id='CUS-000001' AND review_status='PENDING'
  AND received_at >= '2026-09-01' AND received_at < '2026-10-01'
ORDER BY received_at,observation_id;

-- BLOCK P09 | Date workload: add dedicated date index once, before comparing
CREATE INDEX idx_c10_received ON class10_case_search(received_at);

-- BLOCK P10 | Function-wrapped date; may scan an entire covering date index
EXPLAIN FORMAT=TRADITIONAL SELECT COUNT(*) AS matching_observations FROM class10_case_search
WHERE DATE(received_at)='2026-09-15';
SELECT COUNT(*) AS matching_observations FROM class10_case_search
WHERE DATE(received_at)='2026-09-15';

-- BLOCK P11 | Equivalent half-open DATETIME range; test range access
EXPLAIN FORMAT=TRADITIONAL SELECT COUNT(*) AS matching_observations FROM class10_case_search
WHERE received_at >= '2026-09-15' AND received_at < '2026-09-16';
SELECT COUNT(*) AS matching_observations FROM class10_case_search
WHERE received_at >= '2026-09-15' AND received_at < '2026-09-16';

-- BLOCK P12 | Exact predicate-equivalence check, not count-only proof
SELECT COUNT(*) AS predicate_disagreements
FROM class10_case_search
WHERE NOT ((DATE(received_at)='2026-09-15') <=>
 (received_at >= '2026-09-15' AND received_at < '2026-09-16'));
-- Expected 0; received_at is NOT NULL, DATETIME, same day interpretation.

-- BLOCK P13 | Actual broad-vs-range evidence; instructor if time is tight
EXPLAIN ANALYZE SELECT COUNT(*) AS matching_observations FROM class10_case_search
WHERE DATE(received_at)='2026-09-15';
EXPLAIN ANALYZE SELECT COUNT(*) AS matching_observations FROM class10_case_search
WHERE received_at >= '2026-09-15' AND received_at < '2026-09-16';

-- BLOCK P14 | Final evidence and cleanup
SHOW INDEX FROM class10_case_search;
ROLLBACK;
