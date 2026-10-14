-- Section 7 | Run entire file in A to compare scopes side by side.
USE meridian_retail;
SELECT 'NORTH' AS view_scope,COUNT(*) AS visible_profiles FROM class11_support_north_view
UNION ALL
SELECT 'SOUTH',COUNT(*) FROM class11_support_south_view;
SELECT case_id,assigned_team,email_hint,case_status
FROM class11_support_north_view ORDER BY case_id LIMIT 4;
SELECT case_id,assigned_team,email_hint,case_status
FROM class11_support_south_view ORDER BY case_id LIMIT 4;
SHOW GRANTS FOR 'fde11_support_role'@'%';
-- A sees both because it is the instructor. S is restricted to NORTH.
-- Fixed-team views demonstrate a pattern, not native MySQL row-level security.
