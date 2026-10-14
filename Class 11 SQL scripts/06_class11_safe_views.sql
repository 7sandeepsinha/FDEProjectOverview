-- Section 6 | Run entire file in A. Create four restricted read interfaces.
-- SQL SECURITY DEFINER allows restricted users to query these views without
-- base-table SELECT. The creator is their definer in this classroom example.
-- A production deployment should use a carefully scoped dedicated definer.
USE meridian_retail;
CREATE SQL SECURITY DEFINER VIEW class11_support_north_view AS
SELECT p.case_id,p.customer_id,p.assigned_team,p.city,
       CONCAT(LEFT(p.email,2),'***@',SUBSTRING_INDEX(p.email,'@',-1)) AS email_hint,
       sc.review_status AS case_status
FROM class11_case_profiles p
JOIN support_cases sc ON sc.case_id=p.case_id
WHERE p.assigned_team='NORTH';

CREATE SQL SECURITY DEFINER VIEW class11_support_south_view AS
SELECT p.case_id,p.customer_id,p.assigned_team,p.city,
       CONCAT(LEFT(p.email,2),'***@',SUBSTRING_INDEX(p.email,'@',-1)) AS email_hint,
       sc.review_status AS case_status
FROM class11_case_profiles p
JOIN support_cases sc ON sc.case_id=p.case_id
WHERE p.assigned_team='SOUTH';

CREATE SQL SECURITY DEFINER VIEW class11_finance_view AS
SELECT case_id,customer_id,payment_reference
FROM class11_case_profiles;

CREATE SQL SECURITY DEFINER VIEW class11_reporting_view AS
SELECT assigned_team,COUNT(*) AS case_profile_count
FROM class11_case_profiles GROUP BY assigned_team;

GRANT SELECT ON meridian_retail.class11_support_north_view TO 'fde11_support_role'@'%';
GRANT SELECT ON meridian_retail.class11_finance_view TO 'fde11_finance_role'@'%';
GRANT SELECT ON meridian_retail.class11_reporting_view TO 'fde11_reporting_role'@'%';
SHOW GRANTS FOR 'fde11_support_role'@'%';
SELECT * FROM class11_support_north_view ORDER BY case_id LIMIT 4;
-- The SELECT output is safe/minimised: case, status, team, city, masked email.
-- North view 12 rows; South view also 12, but SUPPORT has no grant on it.
