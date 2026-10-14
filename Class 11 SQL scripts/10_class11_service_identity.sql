-- Section 9 | Run entire file in A. Dedicated application principal, never admin.
USE meridian_retail;
-- Generated random credential appears once in Workbench; no need to log in as
-- this identity during class. Treat it as a secret; destroy it after practice.
CREATE USER 'fde11_service_demo'@'localhost' IDENTIFIED BY RANDOM PASSWORD;
GRANT 'fde11_service_role'@'%' TO 'fde11_service_demo'@'localhost';
SET DEFAULT ROLE 'fde11_service_role'@'%' TO 'fde11_service_demo'@'localhost';
GRANT SELECT ON meridian_retail.class11_support_north_view TO 'fde11_service_role'@'%';
SHOW GRANTS FOR 'fde11_service_role'@'%';
SHOW GRANTS FOR 'fde11_service_demo'@'localhost' USING 'fde11_service_role'@'%';
-- Expected: SELECT on ONLY the North safe view via role; no DELETE/UPDATE,
-- no grant on raw class11_case_profiles, no admin privileges.
