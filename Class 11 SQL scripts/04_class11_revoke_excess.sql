-- Section 5 | Run entire file in instructor A after the S-before query succeeds.
USE meridian_retail;
REVOKE SELECT ON meridian_retail.class11_case_profiles FROM 'fde11_support_role'@'%';
SHOW GRANTS FOR 'fde11_support_role'@'%';
-- No replacement access is granted yet; the same support query should now fail.
