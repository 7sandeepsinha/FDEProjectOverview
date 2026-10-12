-- BEFORE a fresh rehearsal ONLY. Close all sessions' active transactions first.
-- SELECT the named block for EACH index that SHOW INDEX confirms exists.
-- Never execute this entire file. Missing indexes cause errors; do not improvise.
USE meridian_retail;
-- BLOCK R00 | Inspect
SHOW INDEX FROM class10_case_search;
-- BLOCK R01 | ONLY if idx_c10_customer exists
DROP INDEX idx_c10_customer ON class10_case_search;
-- BLOCK R02 | ONLY if idx_c10_customer_status_date exists
DROP INDEX idx_c10_customer_status_date ON class10_case_search;
-- BLOCK R03 | ONLY if idx_c10_received exists
DROP INDEX idx_c10_received ON class10_case_search;
-- BLOCK R04 | Confirm only PRIMARY remains; leave data intact
SHOW INDEX FROM class10_case_search;
SELECT COUNT(*) AS observation_rows FROM class10_case_search;
