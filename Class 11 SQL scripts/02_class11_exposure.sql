-- Section 1 | Run entire file in A. Instructor view of the overexposed record.
USE meridian_retail;
SELECT case_id,customer_id,full_name,email,phone,street_address,city,
       payment_reference,internal_note,assigned_team
FROM class11_case_profiles ORDER BY case_id LIMIT 6;
SHOW GRANTS FOR 'fde11_support_role'@'%';
-- Explain: SELECT privilege on the entire profile table lets support retrieve fields
-- it does not need. This is a security incident scenario using wholly synthetic PII.
