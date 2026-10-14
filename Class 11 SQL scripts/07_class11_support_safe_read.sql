-- Section 6 | Run entire file in S. This is the restored ALLOWED access path.
SELECT CURRENT_USER() AS logged_in_as, CURRENT_ROLE() AS active_role;
SELECT case_id,customer_id,assigned_team,city,email_hint,case_status
FROM meridian_retail.class11_support_north_view ORDER BY case_id LIMIT 6;
-- Expected: succeeds; no full email, phone, address, payment or internal notes.
