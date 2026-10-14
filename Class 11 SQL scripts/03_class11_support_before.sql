-- Section 5 | Run entire file in the restricted Workbench connection S.
-- S logs in as fde11_support_demo; use the random password saved at setup.
USE meridian_retail;
SELECT CURRENT_USER() AS logged_in_as, CURRENT_ROLE() AS active_role;
SELECT case_id,full_name,email,phone,street_address,payment_reference,internal_note
FROM class11_case_profiles ORDER BY case_id LIMIT 4;
-- Expected: succeeds before the REVOKE, illustrating excess privilege.
